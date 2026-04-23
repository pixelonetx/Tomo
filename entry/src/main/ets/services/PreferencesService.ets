import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { ModelMode } from '../models/ApiModels';
import { AppSettings, ThemeMode, createDefaultSettings } from '../models/SettingsModels';
import { CONTEXT_EXTENDED_CHAR_BUDGET, CONTEXT_STANDARD_CHAR_BUDGET } from '../shared/Constants';
import { SecureKeyBlob, SecureKeyService } from './SecureKeyService';

export enum PreferenceKey {
  API_KEY = 'apiKey',
  API_KEY_CIPHER = 'apiKeyCipher',
  API_KEY_NONCE = 'apiKeyNonce',
  API_KEY_CONFIGURED = 'apiKeyConfigured',
  MODEL_MODE = 'modelMode',
  THEME_MODE = 'themeMode',
  FONT_SIZE = 'fontSize',
  BACKGROUND_ENABLED = 'backgroundEnabled',
  BACKGROUND_IMAGE_URI = 'backgroundImageUri',
  BACKGROUND_BLUR_RADIUS = 'backgroundBlurRadius',
  BACKGROUND_OPACITY = 'backgroundOpacity',
  WEB_SEARCH_DEFAULT_ENABLED = 'webSearchDefaultEnabled',
  SEARCH_PROVIDER = 'searchProvider',
  SEARCH_API_KEY = 'searchApiKey',
  SEARCH_API_KEY_CIPHER = 'searchApiKeyCipher',
  SEARCH_API_KEY_NONCE = 'searchApiKeyNonce',
  SEARCH_API_KEY_CONFIGURED = 'searchApiKeyConfigured',
  SEARCH_MAX_RESULTS = 'searchMaxResults',
  CONTEXT_WINDOW_CHARS = 'contextWindowChars'
}

const PREFERENCES_NAME: string = 'deepseek_chat_settings';

export class PreferencesService {
  private store: preferences.Preferences | null = null;
  private secureKeyService: SecureKeyService = new SecureKeyService();

  init(context: common.Context): void {
    if (this.store !== null) {
      return;
    }
    try {
      this.store = preferences.getPreferencesSync(context, { name: PREFERENCES_NAME });
    } catch (err) {
      this.store = null;
    }
  }

  loadSettings(): AppSettings {
    const defaults: AppSettings = createDefaultSettings();
    const store = this.requireStore();
    return {
      apiKeyConfigured: this.getBoolean(store, PreferenceKey.API_KEY_CONFIGURED, defaults.apiKeyConfigured),
      modelMode: this.toModelMode(this.getString(store, PreferenceKey.MODEL_MODE, defaults.modelMode)),
      themeMode: this.toThemeMode(this.getString(store, PreferenceKey.THEME_MODE, defaults.themeMode)),
      fontSize: this.getNumber(store, PreferenceKey.FONT_SIZE, defaults.fontSize),
      backgroundEnabled: this.getBoolean(store, PreferenceKey.BACKGROUND_ENABLED, defaults.backgroundEnabled),
      backgroundImageUri: this.getString(store, PreferenceKey.BACKGROUND_IMAGE_URI, defaults.backgroundImageUri),
      backgroundBlurRadius: this.getNumber(store, PreferenceKey.BACKGROUND_BLUR_RADIUS, defaults.backgroundBlurRadius),
      backgroundOpacity: this.getNumber(store, PreferenceKey.BACKGROUND_OPACITY, defaults.backgroundOpacity),
      webSearchDefaultEnabled: this.getBoolean(store, PreferenceKey.WEB_SEARCH_DEFAULT_ENABLED, defaults.webSearchDefaultEnabled),
      searchProvider: this.getString(store, PreferenceKey.SEARCH_PROVIDER, defaults.searchProvider),
      searchApiKeyConfigured: this.getBoolean(store, PreferenceKey.SEARCH_API_KEY_CONFIGURED, defaults.searchApiKeyConfigured),
      searchMaxResults: this.clampSearchMaxResults(this.getNumber(store, PreferenceKey.SEARCH_MAX_RESULTS, defaults.searchMaxResults)),
      contextWindowChars: this.normalizeContextWindowChars(this.getNumber(store, PreferenceKey.CONTEXT_WINDOW_CHARS, defaults.contextWindowChars))
    };
  }

  async saveSettings(settings: AppSettings): Promise<void> {
    const store = this.requireStore();
    try {
      store.putSync(PreferenceKey.API_KEY_CONFIGURED, settings.apiKeyConfigured);
      store.putSync(PreferenceKey.MODEL_MODE, settings.modelMode);
      store.putSync(PreferenceKey.THEME_MODE, settings.themeMode);
      store.putSync(PreferenceKey.FONT_SIZE, settings.fontSize);
      store.putSync(PreferenceKey.BACKGROUND_ENABLED, settings.backgroundEnabled);
      store.putSync(PreferenceKey.BACKGROUND_IMAGE_URI, settings.backgroundImageUri);
      store.putSync(PreferenceKey.BACKGROUND_BLUR_RADIUS, settings.backgroundBlurRadius);
      store.putSync(PreferenceKey.BACKGROUND_OPACITY, settings.backgroundOpacity);
      store.putSync(PreferenceKey.WEB_SEARCH_DEFAULT_ENABLED, settings.webSearchDefaultEnabled);
      store.putSync(PreferenceKey.SEARCH_PROVIDER, settings.searchProvider);
      store.putSync(PreferenceKey.SEARCH_API_KEY_CONFIGURED, settings.searchApiKeyConfigured);
      store.putSync(PreferenceKey.SEARCH_MAX_RESULTS, this.clampSearchMaxResults(settings.searchMaxResults));
      store.putSync(PreferenceKey.CONTEXT_WINDOW_CHARS, this.normalizeContextWindowChars(settings.contextWindowChars));
    } catch (err) {
      throw new Error('Failed to write preferences.');
    }
    await this.flushStore(store);
  }

  async resetSettings(): Promise<AppSettings> {
    const defaults: AppSettings = createDefaultSettings();
    await this.saveSettings(defaults);
    return defaults;
  }

  async setApiKeyConfigured(configured: boolean): Promise<void> {
    const store = this.requireStore();
    try {
      store.putSync(PreferenceKey.API_KEY_CONFIGURED, configured);
    } catch (err) {
      throw new Error('Failed to write api key status.');
    }
    await this.flushStore(store);
  }

  getApiKey(): string {
    const store = this.requireStore();
    return this.getString(store, PreferenceKey.API_KEY, '');
  }

  async loadApiKey(): Promise<string> {
    return this.loadSecret(
      PreferenceKey.API_KEY_CIPHER,
      PreferenceKey.API_KEY_NONCE,
      PreferenceKey.API_KEY,
      PreferenceKey.API_KEY_CONFIGURED
    );
  }

  async saveApiKey(key: string): Promise<void> {
    const store = this.requireStore();
    const cleanKey: string = key.trim();
    if (cleanKey.length === 0) {
      await this.clearApiKey();
      return;
    }
    const blob: SecureKeyBlob = await this.secureKeyService.encryptText(cleanKey);
    try {
      store.putSync(PreferenceKey.API_KEY_CIPHER, blob.cipherHex);
      store.putSync(PreferenceKey.API_KEY_NONCE, blob.nonceHex);
      store.deleteSync(PreferenceKey.API_KEY);
      store.putSync(PreferenceKey.API_KEY_CONFIGURED, true);
    } catch (err) {
      throw new Error('Failed to write api key.');
    }
    await this.flushStore(store);
  }

  async clearApiKey(): Promise<void> {
    const store = this.requireStore();
    try {
      store.deleteSync(PreferenceKey.API_KEY);
      store.deleteSync(PreferenceKey.API_KEY_CIPHER);
      store.deleteSync(PreferenceKey.API_KEY_NONCE);
      store.putSync(PreferenceKey.API_KEY_CONFIGURED, false);
    } catch (err) {
      throw new Error('Failed to clear api key.');
    }
    await this.flushStore(store);
  }

  async setSearchApiKeyConfigured(configured: boolean): Promise<void> {
    const store = this.requireStore();
    try {
      store.putSync(PreferenceKey.SEARCH_API_KEY_CONFIGURED, configured);
    } catch (err) {
      throw new Error('Failed to write search api key status.');
    }
    await this.flushStore(store);
  }

  getSearchApiKey(): string {
    const store = this.requireStore();
    return this.getString(store, PreferenceKey.SEARCH_API_KEY, '');
  }

  async loadSearchApiKey(): Promise<string> {
    return this.loadSecret(
      PreferenceKey.SEARCH_API_KEY_CIPHER,
      PreferenceKey.SEARCH_API_KEY_NONCE,
      PreferenceKey.SEARCH_API_KEY,
      PreferenceKey.SEARCH_API_KEY_CONFIGURED
    );
  }

  async saveSearchApiKey(key: string): Promise<void> {
    const store = this.requireStore();
    const cleanKey: string = key.trim();
    if (cleanKey.length === 0) {
      await this.clearSearchApiKey();
      return;
    }
    const blob: SecureKeyBlob = await this.secureKeyService.encryptText(cleanKey);
    try {
      store.putSync(PreferenceKey.SEARCH_API_KEY_CIPHER, blob.cipherHex);
      store.putSync(PreferenceKey.SEARCH_API_KEY_NONCE, blob.nonceHex);
      store.deleteSync(PreferenceKey.SEARCH_API_KEY);
      store.putSync(PreferenceKey.SEARCH_API_KEY_CONFIGURED, true);
    } catch (err) {
      throw new Error('Failed to write search api key.');
    }
    await this.flushStore(store);
  }

  async clearSearchApiKey(): Promise<void> {
    const store = this.requireStore();
    try {
      store.deleteSync(PreferenceKey.SEARCH_API_KEY);
      store.deleteSync(PreferenceKey.SEARCH_API_KEY_CIPHER);
      store.deleteSync(PreferenceKey.SEARCH_API_KEY_NONCE);
      store.putSync(PreferenceKey.SEARCH_API_KEY_CONFIGURED, false);
    } catch (err) {
      throw new Error('Failed to clear search api key.');
    }
    await this.flushStore(store);
  }

  async setModelMode(mode: ModelMode): Promise<void> {
    const store = this.requireStore();
    try {
      store.putSync(PreferenceKey.MODEL_MODE, mode);
    } catch (err) {
      throw new Error('Failed to write model mode.');
    }
    await this.flushStore(store);
  }

  async setThemeMode(mode: ThemeMode): Promise<void> {
    const store = this.requireStore();
    try {
      store.putSync(PreferenceKey.THEME_MODE, mode);
    } catch (err) {
      throw new Error('Failed to write theme mode.');
    }
    await this.flushStore(store);
  }

  private requireStore(): preferences.Preferences {
    if (this.store === null) {
      throw new Error('PreferencesService must be initialized before use.');
    }
    return this.store;
  }

  private flushStore(store: preferences.Preferences): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      store.flush((err: BusinessError) => {
        if (err) {
          reject(new Error(`Failed to flush preferences: ${err.message}`));
          return;
        }
        resolve();
      });
    });
  }

  private getString(store: preferences.Preferences, key: PreferenceKey, defaultValue: string): string {
    try {
      const value = store.getSync(key, defaultValue);
      if (typeof value === 'string') {
        return value;
      }
    } catch (err) {
      return defaultValue;
    }
    return defaultValue;
  }

  private getNumber(store: preferences.Preferences, key: PreferenceKey, defaultValue: number): number {
    try {
      const value = store.getSync(key, defaultValue);
      if (typeof value === 'number') {
        return value;
      }
    } catch (err) {
      return defaultValue;
    }
    return defaultValue;
  }

  private getBoolean(store: preferences.Preferences, key: PreferenceKey, defaultValue: boolean): boolean {
    try {
      const value = store.getSync(key, defaultValue);
      if (typeof value === 'boolean') {
        return value;
      }
    } catch (err) {
      return defaultValue;
    }
    return defaultValue;
  }

  private async loadSecret(
    cipherKey: PreferenceKey,
    nonceKey: PreferenceKey,
    legacyPlainKey: PreferenceKey,
    configuredKey: PreferenceKey
  ): Promise<string> {
    const store = this.requireStore();
    const cipherHex: string = this.getString(store, cipherKey, '');
    const nonceHex: string = this.getString(store, nonceKey, '');
    if (cipherHex.length > 0 && nonceHex.length > 0) {
      return this.secureKeyService.decryptText({
        cipherHex: cipherHex,
        nonceHex: nonceHex
      });
    }

    const legacyPlainText: string = this.getString(store, legacyPlainKey, '');
    if (legacyPlainText.length === 0) {
      return '';
    }

    const blob: SecureKeyBlob = await this.secureKeyService.encryptText(legacyPlainText);
    try {
      store.putSync(cipherKey, blob.cipherHex);
      store.putSync(nonceKey, blob.nonceHex);
      store.deleteSync(legacyPlainKey);
      store.putSync(configuredKey, true);
    } catch (err) {
      throw new Error('Failed to migrate api key.');
    }
    await this.flushStore(store);
    return legacyPlainText;
  }

  private toModelMode(value: string): ModelMode {
    if (value === ModelMode.REASONER) {
      return ModelMode.REASONER;
    }
    return ModelMode.CHAT;
  }

  private toThemeMode(value: string): ThemeMode {
    if (value === ThemeMode.LIGHT) {
      return ThemeMode.LIGHT;
    }
    if (value === ThemeMode.DARK) {
      return ThemeMode.DARK;
    }
    return ThemeMode.SYSTEM;
  }

  private clampSearchMaxResults(value: number): number {
    if (value < 1) {
      return 1;
    }
    if (value > 5) {
      return 5;
    }
    return Math.floor(value);
  }

  private normalizeContextWindowChars(value: number): number {
    if (value >= CONTEXT_EXTENDED_CHAR_BUDGET) {
      return CONTEXT_EXTENDED_CHAR_BUDGET;
    }
    return CONTEXT_STANDARD_CHAR_BUDGET;
  }
}
