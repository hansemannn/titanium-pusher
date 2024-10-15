//
//  Tweetnacl.swift
//  TweetnaclSwift
//
//  Created by Anh Nguyen on 12/9/16.
//  Copyright © 2016 Bitmark. All rights reserved.
//

import Foundation

// MARK: - Utilities

public struct NaclUtil {

    public enum NaclUtilError: Error {
        case badKeySize
        case badNonceSize
        case badPublicKeySize
        case badSecretKeySize
        case internalError
    }

    static func checkLengths(key: Data, nonce: Data) throws {
        if key.count != TNConstants.Secretbox.keyBytes {
            throw NaclUtilError.badKeySize
        }

        if nonce.count != TNConstants.Secretbox.nonceBytes {
            throw NaclUtilError.badNonceSize
        }
    }

    static func checkBoxLength(publicKey: Data, secretKey: Data) throws {
        if publicKey.count != TNConstants.Box.publicKeyBytes {
            throw NaclUtilError.badPublicKeySize
        }

        if secretKey.count != TNConstants.Box.secretKeyBytes {
            throw NaclUtilError.badSecretKeySize
        }
    }

    public static func secureRandomData(count: Int) throws -> Data {
        // Generation method is platform dependent
        // (The Security framework is only available on Apple platforms).
        #if os(Linux)

        var bytes = [UInt8]()
        for _ in 0..<count {
            let randomByte = UInt8.random(in: UInt8.min...UInt8.max)
            bytes.append(randomByte)
        }
        let randomData = Data(bytes: &bytes, count: count)

        return randomData

        #else

        var randomData = Data(count: count)
        let result = randomData.withUnsafeMutableBytes {
            return SecRandomCopyBytes(kSecRandomDefault, count, $0)
        }
        guard result == errSecSuccess else {
            throw NaclUtilError.internalError
        }

        return randomData

        #endif
    }

    public static func hash(message: Data) throws -> Data {
        var hash = Data(count: TNConstants.Hash.bytes)
        let r = hash.withUnsafeMutableBytes { (hashPointer: UnsafeMutablePointer<UInt8>) -> Int32 in
            return message.withUnsafeBytes({ (messagePointer: UnsafePointer<UInt8>) -> Int32 in
                return crypto_hash_sha512_tweet(hashPointer, messagePointer, UInt64(message.count))
            })
        }

        if r != 0 {
            throw NaclUtilError.internalError
        }

        return hash
    }

    public static func verify(x: Data, y: Data) throws -> Bool {
        if x.count == 0 || y.count == 0 {
            throw NaclUtilError.badKeySize
        }

        if x.count != y.count {
            throw NaclUtilError.badKeySize
        }

        let r = x.withUnsafeBytes { (xPointer: UnsafePointer<UInt8>) -> Int32 in
            return y.withUnsafeBytes({ (yPointer: UnsafePointer<UInt8>) -> Int32 in
                return crypto_verify_32_tweet(xPointer, yPointer)
            })
        }

        return r == 0
    }
}

// MARK: - Internal wrapper

struct NaclWrapper {
    enum NaclWrapperError: Error {
        case invalidParameters
        case internalError
        case creationFailed
    }

    static func crypto_box_keypair(secretKey sk: Data) throws -> (publicKey: Data, secretKey: Data) {
        var pk = Data(count: TNConstants.Box.secretKeyBytes)

        let result = pk.withUnsafeMutableBytes({ (pkPointer: UnsafeMutablePointer<UInt8>) -> Int32 in
            return sk.withUnsafeBytes({ (skPointer: UnsafePointer<UInt8>) -> Int32 in
                return crypto_scalarmult_curve25519_tweet_base(pkPointer, skPointer)
            })
        })

        if result != 0 {
            throw NaclWrapperError.internalError
        }

        return (pk, sk)
    }

    static func crypto_sign_keypair() throws -> (publicKey: Data, secretKey: Data) {
        let sk = try NaclUtil.secureRandomData(count: TNConstants.Sign.secretKeyBytes)

        return try crypto_sign_keypair_seeded(secretKey: sk)
    }

    static func crypto_sign_keypair_seeded(secretKey: Data) throws -> (publicKey: Data, secretKey: Data) {
        var pk = Data(count: TNConstants.Sign.publicKeyBytes)
        var sk = Data(count: TNConstants.Sign.secretKeyBytes)
        sk.replaceSubrange(0..<TNConstants.Sign.publicKeyBytes, with: secretKey.subdata(in: 0..<TNConstants.Sign.publicKeyBytes))

        let result = pk.withUnsafeMutableBytes({ (pkPointer: UnsafeMutablePointer<UInt8>) -> Int32 in
            return sk.withUnsafeMutableBytes({ (skPointer: UnsafeMutablePointer<UInt8>) -> Int32 in
                return crypto_sign_ed25519_tweet_keypair(pkPointer, skPointer)
            })
        })

        if result != 0 {
            throw NaclWrapperError.internalError
        }

        return (pk, sk)
    }
}

// MARK: - Secret-key authenticated encryption

public struct NaclSecretBox {
    public enum NaclSecretBoxError: Error {
        case invalidParameters
        case internalError
        case creationFailed
    }

    public static func secretBox(message: Data, nonce: Data, key: Data) throws -> Data {
        try NaclUtil.checkLengths(key: key, nonce: nonce)

        var m = Data(count: TNConstants.Secretbox.zeroBytes + message.count)
        m.replaceSubrange(TNConstants.Secretbox.zeroBytes..<m.count, with: message)

        var c = Data(count: m.count)

        let result = c.withUnsafeMutableBytes { (cPointer: UnsafeMutablePointer<UInt8>) -> Int32 in
            return m.withUnsafeBytes({ (mPointer: UnsafePointer<UInt8>) -> Int32 in
                return nonce.withUnsafeBytes({ (noncePointer: UnsafePointer<UInt8>) -> Int32 in
                    return key.withUnsafeBytes({ (keyPointer: UnsafePointer<UInt8>) -> Int32 in
                        return crypto_secretbox_xsalsa20poly1305_tweet(cPointer, mPointer, UInt64(m.count), noncePointer, keyPointer)
                    })
                })
            })
        }

        if result != 0 {
            throw NaclSecretBoxError.internalError
        }
        return c.subdata(in: TNConstants.Secretbox.boxZeroBytes..<c.count)
    }

    public static func open(box: Data, nonce: Data, key: Data) throws -> Data {
        try NaclUtil.checkLengths(key: key, nonce: nonce)

        // Fill data
        var c = Data(count: TNConstants.Secretbox.boxZeroBytes + box.count)
        c.replaceSubrange(TNConstants.Secretbox.boxZeroBytes..<c.count, with: box)

        var m = Data(count: c.count)

        let result = m.withUnsafeMutableBytes { (mPointer: UnsafeMutablePointer<UInt8>) -> Int32 in
            return c.withUnsafeBytes({ (cPointer: UnsafePointer<UInt8>) -> Int32 in
                return nonce.withUnsafeBytes({ (noncePointer: UnsafePointer<UInt8>) -> Int32 in
                    return key.withUnsafeBytes({ (keyPointer: UnsafePointer<UInt8>) -> Int32 in
                        return crypto_secretbox_xsalsa20poly1305_tweet_open(mPointer, cPointer, UInt64(c.count), noncePointer, keyPointer)
                    })
                })
            })
        }

        if result != 0 {
            throw NaclSecretBoxError.creationFailed
        }

        return m.subdata(in: TNConstants.Secretbox.zeroBytes..<c.count)
    }
}

// MARK: - Scalar multiplication

public struct NaclScalarMult {
    public enum NaclScalarMultError: Error {
        case invalidParameters
        case internalError
        case creationFailed
    }

    public static func scalarMult(n: Data, p: Data) throws -> Data {
        if n.count != TNConstants.Scalarmult.scalarBytes {
            throw NaclScalarMultError.invalidParameters
        }

        if p.count != TNConstants.Scalarmult.bytes {
            throw NaclScalarMultError.invalidParameters
        }

        var q = Data(count: TNConstants.Scalarmult.bytes)

        let result = q.withUnsafeMutableBytes { (qPointer: UnsafeMutablePointer<UInt8>) -> Int32 in
            return n.withUnsafeBytes({ (nPointer: UnsafePointer<UInt8>) -> Int32 in
                return p.withUnsafeBytes({ (pPointer: UnsafePointer<UInt8>) -> Int32 in
                    return crypto_scalarmult_curve25519_tweet(qPointer, nPointer, pPointer)
                })
            })
        }

        if result != 0 {
            throw NaclScalarMultError.creationFailed
        }

        return q
    }

    public static func base(n: Data) throws -> Data {
        if n.count != TNConstants.Scalarmult.scalarBytes {
            throw NaclScalarMultError.invalidParameters
        }

        var q = Data(count: TNConstants.Scalarmult.bytes)

        let result = q.withUnsafeMutableBytes { (qPointer: UnsafeMutablePointer<UInt8>) -> Int32 in
            return n.withUnsafeBytes({ (nPointer: UnsafePointer<UInt8>) -> Int32 in
                return crypto_scalarmult_curve25519_tweet_base(qPointer, nPointer)
            })
        }

        if result != 0 {
            throw NaclScalarMultError.creationFailed
        }

        return q
    }
}

// MARK: - Public-key authenticated encryption

public struct NaclBox {

    public enum NaclBoxError: Error {
        case invalidParameters
        case internalError
        case creationFailed
    }

    public static func box(message: Data, nonce: Data, publicKey: Data, secretKey: Data) throws -> Data {
        let key = try before(publicKey: publicKey, secretKey: secretKey)
        return try NaclSecretBox.secretBox(message: message, nonce: nonce, key: key)
    }

    public static func before(publicKey: Data, secretKey: Data) throws -> Data {
        try NaclUtil.checkBoxLength(publicKey: publicKey, secretKey: secretKey)

        var k = Data(count: TNConstants.Box.beforeNMBytes)

        let result = k.withUnsafeMutableBytes { (kPointer: UnsafeMutablePointer<UInt8>) -> Int32 in
            return publicKey.withUnsafeBytes({ (pkPointer: UnsafePointer<UInt8>) -> Int32 in
                return secretKey.withUnsafeBytes({ (skPointer: UnsafePointer<UInt8>) -> Int32 in
                    return crypto_box_curve25519xsalsa20poly1305_tweet_beforenm(kPointer, pkPointer, skPointer)
                })
            })
        }

        if result != 0 {
            throw NaclBoxError.creationFailed
        }

        return k
    }

    public static func open(message: Data, nonce: Data, publicKey: Data, secretKey: Data) throws -> Data {
        let k = try before(publicKey: publicKey, secretKey: secretKey)
        return try NaclSecretBox.open(box: message, nonce: nonce, key: k)
    }

    public static func keyPair() throws -> (publicKey: Data, secretKey: Data) {
        let sk = try NaclUtil.secureRandomData(count: TNConstants.Box.secretKeyBytes)

        return try NaclWrapper.crypto_box_keypair(secretKey: sk)
    }

    public static func keyPair(fromSecretKey sk: Data) throws -> (publicKey: Data, secretKey: Data) {
        if sk.count != TNConstants.Box.secretKeyBytes {
            throw NaclBoxError.invalidParameters
        }

        return try NaclWrapper.crypto_box_keypair(secretKey: sk)
    }
}

// MARK: - Signatures

public struct NaclSign {

    public enum NaclSignError: Error {
        case invalidParameters
        case internalError
        case creationFailed
    }

    public static func sign(message: Data, secretKey: Data) throws -> Data {
        if secretKey.count != TNConstants.Sign.secretKeyBytes {
            throw NaclSignError.invalidParameters
        }

        var signedMessage = Data(count: TNConstants.Sign.bytes + message.count)

        let tmpLength = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)

        let result = signedMessage.withUnsafeMutableBytes { (signedMessagePointer: UnsafeMutablePointer<UInt8>) -> Int32 in
            return message.withUnsafeBytes({ (messagePointer: UnsafePointer<UInt8>) -> Int32 in
                return secretKey.withUnsafeBytes({ (secretKeyPointer: UnsafePointer<UInt8>) -> Int32 in
                    return crypto_sign_ed25519_tweet(signedMessagePointer, tmpLength, messagePointer, UInt64(message.count), secretKeyPointer)
                })
            })
        }

        if result != 0 {
            throw NaclSignError.internalError
        }

        return signedMessage
    }

    public static func signOpen(signedMessage: Data, publicKey: Data) throws -> Data {
        if publicKey.count != TNConstants.Sign.publicKeyBytes {
            throw NaclSignError.invalidParameters
        }

        var tmp = Data(count: signedMessage.count)
        let tmpLength = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)

        let result = tmp.withUnsafeMutableBytes { (tmpPointer: UnsafeMutablePointer<UInt8>) -> Int32 in
            return signedMessage.withUnsafeBytes({ (signMessagePointer: UnsafePointer<UInt8>) -> Int32 in
                return publicKey.withUnsafeBytes({ (publicKeyPointer: UnsafePointer<UInt8>) -> Int32 in
                    return crypto_sign_ed25519_tweet_open(tmpPointer, tmpLength, signMessagePointer, UInt64(signedMessage.count), publicKeyPointer)
                })
            })
        }

        if result != 0 {
            throw NaclSignError.creationFailed
        }

        return tmp
    }

    public static func signDetached(message: Data, secretKey: Data) throws -> Data {
        let signedMessage = try sign(message: message, secretKey: secretKey)

        let sig = signedMessage.subdata(in: 0..<TNConstants.Sign.bytes)

        return sig as Data
    }

    public static func signDetachedVerify(message: Data, sig: Data, publicKey: Data) throws -> Bool {
        if sig.count != TNConstants.Sign.bytes {
            throw NaclSignError.invalidParameters
        }

        if publicKey.count != TNConstants.Sign.publicKeyBytes {
            throw NaclSignError.invalidParameters
        }

        var sm = Data()

        var m = Data(count: TNConstants.Sign.bytes + message.count)

        sm.append(sig )
        sm.append(message)

        let tmpLength = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)

        let result = m.withUnsafeMutableBytes { (mPointer: UnsafeMutablePointer<UInt8>) -> Int32 in
            return sm.withUnsafeBytes({ (smPointer: UnsafePointer<UInt8>) -> Int32 in
                return publicKey.withUnsafeBytes({ (publicKeyPointer: UnsafePointer<UInt8>) -> Int32 in
                    return crypto_sign_ed25519_tweet_open(mPointer, tmpLength, smPointer, UInt64(sm.count), publicKeyPointer)
                })
            })
        }

        return result == 0
    }

    public struct KeyPair {
        public static func keyPair() throws -> (publicKey: Data, secretKey: Data) {
            return try NaclWrapper.crypto_sign_keypair()
        }

        public static func keyPair(fromSecretKey secretKey: Data) throws -> (publicKey: Data, secretKey: Data) {
            if secretKey.count != TNConstants.Sign.secretKeyBytes {
                throw NaclSignError.invalidParameters
            }

            let pk = secretKey.subdata(in: TNConstants.Sign.publicKeyBytes..<TNConstants.Sign.secretKeyBytes)

            return (pk, secretKey)
        }

        public static func keyPair(fromSeed seed: Data) throws -> (publicKey: Data, secretKey: Data) {
            if seed.count != TNConstants.Sign.seedBytes {
                throw NaclSignError.invalidParameters
            }

            return try NaclWrapper.crypto_sign_keypair_seeded(secretKey: seed)
        }
    }
}
