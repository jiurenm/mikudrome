declare global {
  interface Window {
    __APP_CONFIG__?: {
      apiBaseUrl?: string;
      cookie?: string;
    };
  }
}

const buildTimeApiBaseUrl = import.meta.env.VITE_API_BASE_URL ?? "";

export function selectApiBaseUrl(runtimeApiBaseUrl = "", fallbackApiBaseUrl = ""): string {
  const runtimeValue = runtimeApiBaseUrl.trim();
  if (runtimeValue) {
    return runtimeValue;
  }

  return fallbackApiBaseUrl.trim();
}

export function resolveApiBaseUrl(): string {
  const runtimeApiBaseUrl =
    typeof window === "undefined" ? "" : window.__APP_CONFIG__?.apiBaseUrl ?? "";

  return selectApiBaseUrl(runtimeApiBaseUrl, buildTimeApiBaseUrl);
}

export function resolveApiCookie(): string {
  const runtimeCookie = typeof window === "undefined" ? "" : window.__APP_CONFIG__?.cookie ?? "";

  return runtimeCookie.trim();
}

export function buildApiUrl(path: string, baseUrl = resolveApiBaseUrl()): string {
  if (!baseUrl) return path;
  return `${baseUrl.replace(/\/+$/, "")}${path}`;
}
