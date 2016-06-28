# Cypress Core Extension

## Installing

```bash
npm install @cypress/core-extension
```

## Developing

**Install**

```bash
npm install
```

**Building**

```bash
npm run build
```

**Watching**

```bash
npm run watch
```

1. Open Chrome
2. Go into Extensions
3. Check **Developer Mode**
4. Click **Load unpacked extension...**
5. Choose **cypress-core-extension/dist** directory
6. Click **background page** to debug `background.js`
7. Click **Reload (⌘R)** to pull in changes to `manifest.json`

## Changelog

#### 0.3.1 - *(06/28/16)*
- remove querying by tab url

#### 0.3.0 - *(06/12/16)*
- added take:screenshot

#### 0.2.0 - *(05/22/16)*
- notify on cookie change

#### 0.1.3 - *(05/16/16)*
- new tab content + phrasing

#### 0.1.2 - *(05/15/16)*
- ignore theme/Cached Theme.pak

#### 0.1.1 - *(05/15/16)*
- set lodash as dep not devDep

#### 0.1.0 - *(05/15/16)*
- initial release
- implements cookie automation
