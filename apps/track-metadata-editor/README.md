# Track Metadata Editor

## Development

Install dependencies:

```bash
npm ci
```

Run the Next development server:

```bash
API_BASE_URL=http://127.0.0.1:8080 npm run dev
```

Open:

```text
http://127.0.0.1:4173
```

The browser talks to same-origin `/api/*` paths for the local metadata backend. Next proxies those requests to `API_BASE_URL`.

If the backend requires a fixed cookie, set `API_COOKIE` on the server process:

```bash
API_BASE_URL=http://127.0.0.1:8080 API_COOKIE='session=YOUR_SESSION' npm run dev
```

`API_COOKIE` is not exposed to browser JavaScript.

## VocaDB matching

The editor can match a local album against VocaDB from the album explorer.

- Use `Match VocaDB` on an album row.
- Select a search result, or paste a VocaDB album URL/ID.
- Review per-track field suggestions.
- Empty local fields are selected by default.
- Existing local values are shown but not selected for overwrite by default.
- Confirmed album changes are saved with one backend batch PATCH.

Browser JavaScript calls the public VocaDB API directly for album search and album details.

## Test

Run tests once:

```bash
npm run test
```

Run tests in watch mode:

```bash
npm run test:watch
```

## Build

Create a production build:

```bash
npm run build
```

Run the standalone production server:

```bash
API_BASE_URL=http://127.0.0.1:8080 npm run start
```

## Docker

Copy the example environment file and set the backend API origin:

```bash
cp .env.example .env
```

Build and run with Docker Compose:

```bash
docker compose up --build
```

Build Docker image manually:

```bash
docker build -t track-metadata-editor .
```

Run the image manually:

```bash
docker run --rm -p 4173:4173 -e API_BASE_URL=http://YOUR_SERVER_IP:8080 -e 'API_COOKIE=session=YOUR_SESSION' track-metadata-editor
```

If the backend does not require a fixed cookie, omit `API_COOKIE`:

```bash
docker run --rm -p 4173:4173 -e API_BASE_URL=http://YOUR_SERVER_IP:8080 track-metadata-editor
```
