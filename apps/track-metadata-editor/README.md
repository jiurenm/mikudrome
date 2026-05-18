# Track Metadata Editor

## Development

Install dependencies:

```bash
npm ci
```

Run the development server:

```bash
npm run dev
```

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

## Docker

This image serves static frontend files with Nginx only. It does not proxy `/api`.
The container writes `/env.js` when it starts, so `API_BASE_URL` can be changed without rebuilding.
If `API_BASE_URL` is empty, the app falls back to same-origin `/api`.
Set `API_COOKIE` to send a Cookie header with API requests.

Set `API_BASE_URL` first if your API is on another origin, and set `API_COOKIE` if the backend requires a cookie (for example, copy `.env.example` to `.env` and edit it):

```bash
cp .env.example .env
```

Then build and run with Docker Compose:

```bash
docker compose up --build
```

Build Docker image manually:

```bash
docker build -t track-metadata-editor .
```

Run the image and inject the API base URL and cookie at container startup:

```bash
docker run --rm -p 4173:80 -e API_BASE_URL=http://YOUR_SERVER_IP:8080 -e 'API_COOKIE=session=YOUR_SESSION' track-metadata-editor
```

If the API is served from the same origin, leave `API_BASE_URL` empty:

```bash
docker run --rm -p 4173:80 track-metadata-editor
```
