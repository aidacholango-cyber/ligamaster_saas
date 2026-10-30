# Imagen del inicio: vidrio roto

Herramienta: edición integrada `image_gen`, con transparencia.
Referencia: versión anterior del logo de LigaMaster, conservando el jugador y la paleta.
Resultado: `assets/images/ligamaster_inicio_vidrio.png`.

Prompt utilizado:

> Edit target: attached LigaMaster brand illustration. Preserve the central running football player silhouette, football, blue/green/magenta color arrangement, and exact crisp lettering 'LIGAMASTER' and smaller 'SAAS'. COMPLETELY REMOVE every paper element, paper texture, torn paper edge and layered paper background. Instead create an elegant shattered-glass effect: an irregular clear glass pane behind the player with fine sharp radial cracks and a few floating angular translucent glass shards around the edges. Glass must look clean, transparent, glossy and sophisticated, with restrained indigo #4351BF, emerald #166534 and magenta #BC1676 reflections on the facets. Keep central player and lettering fully readable, flat sharp brand graphics in front of the clear glass, with no cracks crossing their faces. The glass effect should feel like a dynamic football player breaking through a crystal pane, airy and polished rather than a busy explosion. Truly transparent outer background so it blends on a very pale gray login screen. No opaque white panel, no paper, no rectangular solid background, no extra words or icons. Generous outer margin, balanced 5:4 composition, high resolution raster asset for the left side of a login screen.

El fondo de la pantalla se extiende con facetas, reflejos y grietas dibujados mediante `CustomPainter` en `lib/widgets/fondo_vidrio_inicio.dart`. Es decorativo y no intercepta eventos; el formulario opaco se conserva por encima.
