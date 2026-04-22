import { ModelMode } from './ApiModels';

export enum ThemeMode {
  SYSTEM = 'system',
  LIGHT = 'light',
  DARK = 'dark'
}

export interface AppSettings {
  apiKeyConfigured: boolean;
  modelMode: ModelMode;
  themeMode: ThemeMode;
  fontSize: number;
  backgroundEnabled: boolean;
  backgroundImageUri: string;
  backgroundBlurRadius: number;
  backgroundOpacity: number;
  webSearchDefaultEnabled: boolean;
  searchProvider: string;
  searchApiKeyConfigured: boolean;
  searchMaxResults: number;
}

export function createDefaultSettings(): AppSettings {
  return {
    apiKeyConfigured: false,
    modelMode: ModelMode.CHAT,
    themeMode: ThemeMode.SYSTEM,
    fontSize: 15,
    backgroundEnabled: false,
    backgroundImageUri: '',
    backgroundBlurRadius: 20,
    backgroundOpacity: 0.3,
    webSearchDefaultEnabled: false,
    searchProvider: 'tavily',
    searchApiKeyConfigured: false,
    searchMaxResults: 5
  };
}
