{{flutter_js}}
{{flutter_build_config}}

const startup = document.querySelector('#flutter-startup');

async function startGembalaKecil() {
  // Older preview builds registered Flutter's generated service worker. Remove
  // it so a stale app shell cannot keep serving a blank/obsolete bundle.
  if ('serviceWorker' in navigator) {
    const registrations = await navigator.serviceWorker.getRegistrations();
    if (registrations.length > 0) {
      await Promise.all(registrations.map((item) => item.unregister()));
      if (navigator.serviceWorker.controller &&
          sessionStorage.getItem('gembala-sw-cleared') !== 'yes') {
        sessionStorage.setItem('gembala-sw-cleared', 'yes');
        location.reload();
        return;
      }
    }
  }

  await _flutter.loader.load({
    config: {
      // Keep local previews and production builds independent from the Google
      // CanvasKit CDN. Flutter already bundles these files in build/web.
      canvasKitBaseUrl: 'canvaskit/',
    },
    onEntrypointLoaded: async (engineInitializer) => {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
      startup?.remove();
    },
  });
}

startGembalaKecil().catch((error) => {
  console.error('Gembala Kecil failed to start', error);
  if (!startup) return;
  startup.classList.add('failed');
  startup.querySelector('.startup-copy').textContent =
      'Aplikasi belum dapat dimuat. Silakan muat ulang halaman.';
});
