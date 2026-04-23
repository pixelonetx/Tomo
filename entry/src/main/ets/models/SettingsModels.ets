import { ModelMode } from './ApiModels';
import { CONTEXT_STANDARD_CHAR_BUDGET } from '../shared/Constants';

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
  contextWindowChars: number;
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
    searchMaxResults: 5,
    contextWindowChars: CONTEXT_STANDARD_CHAR_BUDGET
  };
}
