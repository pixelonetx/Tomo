import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { ModelMode } from '../models/ApiModels';
import { AppSettings, ThemeMode, createDefaultSettings } from '../models/SettingsModels';

export enum PreferenceKey {
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
  SEARCH_API_KEY_CONFIGURED = 'searchApiKeyConfigured',
  SEARCH_MAX_RESULTS = 'searchMaxResults'
}

const PREFERENCES_NAME: string = 'deepseek_chat_settings';

export class PreferencesService {
  private store: preferences.Preferences | null = null;

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
      searchMaxResults: this.clampSearchMaxResults(this.getNumber(store, PreferenceKey.SEARCH_MAX_RESULTS, defaults.searchMaxResults))
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

  async setSearchApiKeyConfigured(configured: boolean): Promise<void> {
    const store = this.requireStore();
    try {
      store.putSync(PreferenceKey.SEARCH_API_KEY_CONFIGURED, configured);
    } catch (err) {
      throw new Error('Failed to write search api key status.');
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
}
