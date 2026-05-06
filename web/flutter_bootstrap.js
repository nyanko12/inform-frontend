{{flutter_js}}
{{flutter_build_config}}

const isMobile = /iPhone|iPad|iPod|Android/i.test(navigator.userAgent);

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    let appRunner = await engineInitializer.initializeEngine({
      renderer: isMobile ? 'html' : 'canvaskit',
    });
    await appRunner.runApp();
  }
});
