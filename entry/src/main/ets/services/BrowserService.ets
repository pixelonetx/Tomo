import { common, Want } from '@kit.AbilityKit';

export function normalizeWebUrl(rawUrl: string): string {
  const url: string = rawUrl.trim();
  if (url.length === 0) {
    return '';
  }
  const lowerUrl: string = url.toLowerCase();
  if (lowerUrl.startsWith('https://') || lowerUrl.startsWith('http://')) {
    return url;
  }
  return '';
}

export function getDisplayUrl(rawUrl: string): string {
  const url: string = normalizeWebUrl(rawUrl);
  if (url.length === 0) {
    return rawUrl.trim();
  }
  return url.replace(/^https?:\/\//i, '');
}

export async function openUrlInSystemBrowser(context: common.UIAbilityContext, rawUrl: string): Promise<boolean> {
  const url: string = normalizeWebUrl(rawUrl);
  if (url.length === 0) {
    return false;
  }

  const want: Want = {
    action: 'ohos.want.action.viewData',
    uri: url
  };

  try {
    await context.startAbility(want);
    return true;
  } catch (_err) {
    return false;
  }
}
