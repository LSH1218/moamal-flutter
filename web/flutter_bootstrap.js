{{flutter_js}}
{{flutter_build_config}}

// Give each build a distinct entrypoint URL, including for returning visitors
// controlled by an older Flutter service worker. Do not touch auth/session data.
const release = {{flutter_service_worker_version}};
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) {
    build.mainJsPath += '?release=' + encodeURIComponent(release);
  }
}

async function startMoamal() {
  if ('serviceWorker' in navigator) {
    try {
      const registrations = await navigator.serviceWorker.getRegistrations();
      for (const registration of registrations) {
        const worker = registration.active || registration.waiting || registration.installing;
        if (worker && new URL(worker.scriptURL).pathname.endsWith('/flutter_service_worker.js')) {
          await registration.unregister();
        }
      }
    } catch (error) {
      console.warn('Could not retire the old Flutter offline cache.', error);
    }
  }
  await _flutter.loader.load();
}
startMoamal();
