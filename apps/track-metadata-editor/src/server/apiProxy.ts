interface ProxyBackendRequestOptions {
  method: "GET" | "PATCH";
  body?: BodyInit | null;
  contentType?: string | null;
}

const RESPONSE_HEADERS_TO_FORWARD = ["content-type", "cache-control", "etag", "last-modified"];

function resolveApiBaseUrl(): string | null {
  const value = process.env.API_BASE_URL?.trim() ?? "";
  return value === "" ? null : value.replace(/\/+$/, "");
}

function buildBackendUrl(path: string): string | null {
  const apiBaseUrl = resolveApiBaseUrl();
  if (apiBaseUrl == null) {
    return null;
  }

  return `${apiBaseUrl}${path}`;
}

function buildRequestHeaders(contentType?: string | null): Headers {
  const headers = new Headers();
  const apiCookie = process.env.API_COOKIE?.trim() ?? "";

  if (contentType != null && contentType !== "") {
    headers.set("content-type", contentType);
  }

  if (apiCookie !== "") {
    headers.set("cookie", apiCookie);
  }

  return headers;
}

function buildResponseHeaders(sourceHeaders: Headers): Headers {
  const headers = new Headers();

  for (const headerName of RESPONSE_HEADERS_TO_FORWARD) {
    const value = sourceHeaders.get(headerName);
    if (value != null) {
      headers.set(headerName, value);
    }
  }

  return headers;
}

export async function proxyBackendRequest(
  path: string,
  options: ProxyBackendRequestOptions
): Promise<Response> {
  const backendUrl = buildBackendUrl(path);
  if (backendUrl == null) {
    return Response.json({ error: "API_BASE_URL is not configured." }, { status: 500 });
  }

  const backendResponse = await fetch(backendUrl, {
    method: options.method,
    headers: buildRequestHeaders(options.contentType),
    body: options.body ?? undefined,
    cache: "no-store"
  });

  return new Response(backendResponse.body, {
    status: backendResponse.status,
    statusText: backendResponse.statusText,
    headers: buildResponseHeaders(backendResponse.headers)
  });
}
