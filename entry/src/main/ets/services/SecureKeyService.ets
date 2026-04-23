import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { huks } from '@kit.UniversalKeystoreKit';

export interface SecureKeyBlob {
  cipherHex: string;
  nonceHex: string;
}

const HUKS_ALIAS: string = 'tomo_api_key_storage_v1';
const AAD_TEXT: string = 'TomoApiKeyStorageV1';
const GCM_TAG_LENGTH: number = 16;

export class SecureKeyService {
  async encryptText(plainText: string): Promise<SecureKeyBlob> {
    await this.ensureKey();
    let nonce: Uint8Array;
    try {
      nonce = cryptoFramework.createRandom().generateRandomSync(12).data;
    } catch (err) {
      throw new Error('Failed to create secure nonce.');
    }
    const options: huks.HuksOptions = {
      properties: this.getEncryptProperties(nonce),
      inData: this.stringToUint8Array(plainText)
    };
    try {
      const session = await huks.initSession(HUKS_ALIAS, options);
      const result = await huks.finishSession(session.handle, options);
      const cipherData: Uint8Array = result.outData as Uint8Array;
      return {
        cipherHex: this.uint8ArrayToHex(cipherData),
        nonceHex: this.uint8ArrayToHex(nonce)
      };
    } catch (err) {
      throw new Error('Failed to encrypt api key.');
    }
  }

  async decryptText(blob: SecureKeyBlob): Promise<string> {
    if (blob.cipherHex.length === 0 || blob.nonceHex.length === 0) {
      return '';
    }
    const cipherData: Uint8Array = this.hexToUint8Array(blob.cipherHex);
    if (cipherData.length <= GCM_TAG_LENGTH) {
      throw new Error('Secure key payload is invalid.');
    }
    const nonce: Uint8Array = this.hexToUint8Array(blob.nonceHex);
    const encryptedData: Uint8Array = cipherData.slice(0, cipherData.length - GCM_TAG_LENGTH);
    const options: huks.HuksOptions = {
      properties: this.getDecryptProperties(nonce, cipherData),
      inData: encryptedData
    };
    try {
      const session = await huks.initSession(HUKS_ALIAS, options);
      const result = await huks.finishSession(session.handle, options);
      return this.uint8ArrayToString(result.outData as Uint8Array);
    } catch (err) {
      throw new Error('Failed to decrypt api key.');
    }
  }

  private async ensureKey(): Promise<void> {
    const options: huks.HuksOptions = {
      properties: this.getGenerateProperties()
    };
    try {
      await huks.generateKeyItem(HUKS_ALIAS, options);
    } catch (err) {
      // Existing aliases fail generation but remain usable for initSession.
    }
  }

  private getGenerateProperties(): Array<huks.HuksParam> {
    return [{
      tag: huks.HuksTag.HUKS_TAG_ALGORITHM,
      value: huks.HuksKeyAlg.HUKS_ALG_AES
    }, {
      tag: huks.HuksTag.HUKS_TAG_KEY_SIZE,
      value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_128
    }, {
      tag: huks.HuksTag.HUKS_TAG_PURPOSE,
      value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT | huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT
    }];
  }

  private getEncryptProperties(nonce: Uint8Array): Array<huks.HuksParam> {
    return [{
      tag: huks.HuksTag.HUKS_TAG_ALGORITHM,
      value: huks.HuksKeyAlg.HUKS_ALG_AES
    }, {
      tag: huks.HuksTag.HUKS_TAG_KEY_SIZE,
      value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_128
    }, {
      tag: huks.HuksTag.HUKS_TAG_PURPOSE,
      value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT
    }, {
      tag: huks.HuksTag.HUKS_TAG_PADDING,
      value: huks.HuksKeyPadding.HUKS_PADDING_NONE
    }, {
      tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE,
      value: huks.HuksCipherMode.HUKS_MODE_GCM
    }, {
      tag: huks.HuksTag.HUKS_TAG_NONCE,
      value: nonce
    }, {
      tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA,
      value: this.stringToUint8Array(AAD_TEXT)
    }];
  }

  private getDecryptProperties(nonce: Uint8Array, cipherData: Uint8Array): Array<huks.HuksParam> {
    return [{
      tag: huks.HuksTag.HUKS_TAG_ALGORITHM,
      value: huks.HuksKeyAlg.HUKS_ALG_AES
    }, {
      tag: huks.HuksTag.HUKS_TAG_KEY_SIZE,
      value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_128
    }, {
      tag: huks.HuksTag.HUKS_TAG_PURPOSE,
      value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT
    }, {
      tag: huks.HuksTag.HUKS_TAG_PADDING,
      value: huks.HuksKeyPadding.HUKS_PADDING_NONE
    }, {
      tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE,
      value: huks.HuksCipherMode.HUKS_MODE_GCM
    }, {
      tag: huks.HuksTag.HUKS_TAG_NONCE,
      value: nonce
    }, {
      tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA,
      value: this.stringToUint8Array(AAD_TEXT)
    }, {
      tag: huks.HuksTag.HUKS_TAG_AE_TAG,
      value: cipherData.slice(cipherData.length - GCM_TAG_LENGTH)
    }];
  }

  private stringToUint8Array(value: string): Uint8Array {
    const data: number[] = [];
    for (let i = 0; i < value.length; i++) {
      data.push(value.charCodeAt(i));
    }
    return new Uint8Array(data);
  }

  private uint8ArrayToString(data: Uint8Array): string {
    let value: string = '';
    for (let i = 0; i < data.length; i++) {
      value += String.fromCharCode(data[i]);
    }
    return value;
  }

  private uint8ArrayToHex(data: Uint8Array): string {
    let hex: string = '';
    for (let i = 0; i < data.length; i++) {
      const part: string = data[i].toString(16);
      hex += part.length === 1 ? `0${part}` : part;
    }
    return hex;
  }

  private hexToUint8Array(hex: string): Uint8Array {
    if (hex.length % 2 !== 0) {
      throw new Error('Invalid hex payload.');
    }
    const data: Uint8Array = new Uint8Array(hex.length / 2);
    for (let i = 0; i < hex.length; i += 2) {
      data[i / 2] = Number.parseInt(hex.substring(i, i + 2), 16);
    }
    return data;
  }
}
