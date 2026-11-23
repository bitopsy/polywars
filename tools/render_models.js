// Renders exported brick models (tools/s3o_export.py) with three.js in headless Chromium (Playwright).
//
//   node tools/render_models.js models.json outdir [--size 512] [--views iso,back,top] [--names a,b] [--team 0|1]
//   node tools/render_models.js models.json outdir --scene scene.json --width 1536 --height 768
//
// Needs `npm i three@0.160.0` (NODE_PATH or local node_modules) and playwright. Dev tool only: the game
// itself ships the pre-baked PNGs.
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');
const THREE_SRC = fs.readFileSync(require.resolve('three'), 'utf8');   // build/three.cjs

const args = process.argv.slice(2);
const modelsFile = args[0], outDir = args[1];
const opt = (k, d) => { const i = args.indexOf('--' + k); return i >= 0 ? args[i + 1] : d; };
const SIZE = parseInt(opt('size', '512'));
const W = parseInt(opt('width', SIZE)), H = parseInt(opt('height', SIZE));
const VIEWS = opt('views', 'iso').split(',');
const SHADOW = parseFloat(opt('shadow', '0.32'));
const NAMES = opt('names', '') ? opt('names', '').split(',') : null;
const SCENE = opt('scene', '') ? JSON.parse(fs.readFileSync(opt('scene', ''))) : null;
const models = JSON.parse(fs.readFileSync(modelsFile));
fs.mkdirSync(outDir, { recursive: true });

const html = `<!doctype html><html><body style="margin:0;background:transparent">
<canvas id="c" width="${W}" height="${H}"></canvas></body></html>`;

// everything below runs inside the page
function pageSetup({ W, H }) {
  const canvas = document.getElementById('c');
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, preserveDrawingBuffer: true });
  renderer.setSize(W, H, false);
  renderer.setClearColor(0x000000, 0);
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;
  const envScene = new THREE.Scene();
  envScene.background = new THREE.Color(0x8890a0);
  const mk = (w, h, x, y, z, c, i) => { const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial({ color: new THREE.Color(c).multiplyScalar(i), side: THREE.DoubleSide })); m.position.set(x, y, z); m.lookAt(0, 0, 0); envScene.add(m); };
  mk(60, 40, 0, 50, 20, 0xffffff, 3.2); mk(30, 60, -50, 10, 30, 0xffeedd, 1.6); mk(30, 60, 50, 10, -20, 0xbfd4ff, 1.2); mk(80, 20, 0, -40, 0, 0x404858, 0.6);
  const pm = new THREE.PMREMGenerator(renderer);
  window.__R = { renderer, env: pm.fromScene(envScene, 0.04).texture, canvas };

  window.__mesh = (m, team) => {
    const g = new THREE.BufferGeometry();
    const n = m.pos.length / 3;
    const col = new Float32Array(m.col);
    const em = new Float32Array(n * 3);
    for (let i = 0; i < n; i++) {
      if (m.team[i] > 0) { const t = m.team[i] >= 0.99 ? 1 : 0.6; for (let c = 0; c < 3; c++) col[i * 3 + c] = col[i * 3 + c] * (1 - t) + team[c] * t * 0.8; }
      if (m.glow[i]) { for (let c = 0; c < 3; c++) em[i * 3 + c] = col[i * 3 + c]; }
    }
    const lin = col.map(v => Math.pow(v, 2.2)), linE = em.map(v => Math.pow(v, 2.2));
    const idx = [];
    for (let q = 0; q < n; q += 4) idx.push(q, q + 1, q + 2, q, q + 2, q + 3);
    g.setAttribute('position', new THREE.BufferAttribute(new Float32Array(m.pos), 3));
    g.setAttribute('normal', new THREE.BufferAttribute(new Float32Array(m.nrm), 3));
    g.setAttribute('color', new THREE.BufferAttribute(lin, 3));
    g.setAttribute('emis', new THREE.BufferAttribute(linE, 3));
    g.setIndex(idx);
    const mat = new THREE.MeshPhysicalMaterial({ vertexColors: true, roughness: 0.32, metalness: 0.0, clearcoat: 0.55, clearcoatRoughness: 0.25, envMapIntensity: 0.9 });
    mat.onBeforeCompile = (sh) => {
      sh.vertexShader = sh.vertexShader.replace('#include <common>', '#include <common>\nattribute vec3 emis; varying vec3 vEmis;').replace('#include <begin_vertex>', '#include <begin_vertex>\nvEmis = emis;');
      sh.fragmentShader = sh.fragmentShader.replace('#include <common>', '#include <common>\nvarying vec3 vEmis;').replace('#include <emissivemap_fragment>', '#include <emissivemap_fragment>\ntotalEmissiveRadiance += vEmis * 1.6;');
    };
    const mesh = new THREE.Mesh(g, mat);
    mesh.castShadow = true; mesh.receiveShadow = true;
    return mesh;
  };
  window.__lights = (scene, r, shadowOpacity) => {
    const ground = new THREE.Mesh(new THREE.PlaneGeometry(2000, 2000), new THREE.ShadowMaterial({ opacity: shadowOpacity }));
    ground.rotation.x = -Math.PI / 2; ground.receiveShadow = true; ground.position.y = -0.02; scene.add(ground);
    scene.add(new THREE.HemisphereLight(0xdfe8ff, 0x6a5f55, 0.55));
    const key = new THREE.DirectionalLight(0xfff4e6, 1.9);
    key.position.set(-r * 1.6, r * 2.6, r * 1.8);
    key.castShadow = true; key.shadow.mapSize.set(4096, 4096);
    const sc = key.shadow.camera; sc.left = -r * 2; sc.right = r * 2; sc.top = r * 2; sc.bottom = -r * 2; sc.near = 0.1; sc.far = r * 9; key.shadow.bias = -0.0006; key.shadow.radius = 4;
    scene.add(key);
    const rim = new THREE.DirectionalLight(0xaec8ff, 0.7); rim.position.set(r * 2, r, -r * 2); scene.add(rim);
    return key;
  };
}

(async () => {
  const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist', '--use-angle=swiftshader'] });
  const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  await page.setContent(html);
  await page.addScriptTag({ content: '(function(){var module={exports:{}};var exports=module.exports;' + THREE_SRC + ';window.THREE=module.exports;})();' });
  await page.evaluate(pageSetup, { W, H });

  if (SCENE) {
    // scene mode: SCENE = { background:[top,bottom] css colours, camera:{pos:[x,y,z],target:[x,y,z],fov}, items:[{model,x,z,ry,s,team}], plate:{w,d,color,studs}, radius }
    const used = {}; for (const it of SCENE.items) used[it.model] = models[it.model];
    await page.evaluate(({ SCENE, used, W, H }) => {
      const { renderer, env } = window.__R;
      const scene = new THREE.Scene();
      scene.environment = env;
      const c2 = document.createElement('canvas'); c2.width = 4; c2.height = 256;
      const x2 = c2.getContext('2d'); const gr = x2.createLinearGradient(0, 0, 0, 256);
      gr.addColorStop(0, SCENE.background[0]); gr.addColorStop(1, SCENE.background[1]); x2.fillStyle = gr; x2.fillRect(0, 0, 4, 256);
      const tex = new THREE.CanvasTexture(c2); tex.colorSpace = THREE.SRGBColorSpace; scene.background = tex;
      // baseplate with studs
      if (SCENE.plate) {
        const p = SCENE.plate;
        const pm = new THREE.MeshPhysicalMaterial({ color: new THREE.Color(p.color), roughness: 0.35, clearcoat: 0.5 });
        const slab = new THREE.Mesh(new THREE.BoxGeometry(p.w, 4, p.d), pm); slab.position.set(0, -2.02, 0); slab.receiveShadow = true; slab.castShadow = true; scene.add(slab);
        const pitch = p.pitch || 8;
        const nx = Math.floor(p.w / pitch), nz = Math.floor(p.d / pitch);
        const stud = new THREE.InstancedMesh(new THREE.CylinderGeometry(p.pitch * 0.31 || 2.5, p.pitch * 0.31 || 2.5, 2.1, 14), pm, nx * nz);
        const dm = new THREE.Object3D(); let k = 0;
        for (let i = 0; i < nx; i++) for (let j = 0; j < nz; j++) { dm.position.set(-p.w / 2 + pitch * (i + 0.5), 1.05, -p.d / 2 + pitch * (j + 0.5)); dm.updateMatrix(); stud.setMatrixAt(k++, dm.matrix); }
        stud.castShadow = true; stud.receiveShadow = true; scene.add(stud);
      }
      const TEAM = { aegis: [0.18, 0.55, 1.0], vanta: [1.0, 0.22, 0.16] };
      for (const it of SCENE.items) {
        const m = used[it.model]; const mesh = window.__mesh(m, it.team || TEAM[m.faction]);
        mesh.position.set(it.x, it.y || 0, it.z); mesh.rotation.y = (it.ry || 0) * Math.PI / 180; mesh.scale.setScalar(it.s || 1);
        scene.add(mesh);
      }
      const key = window.__lights(scene, SCENE.radius, 0.35);
      key.position.set(-SCENE.radius * 0.8, SCENE.radius * 1.6, SCENE.radius * 0.9);
      const cam = new THREE.PerspectiveCamera(SCENE.camera.fov, W / H, 1, 8000);
      cam.position.set(...SCENE.camera.pos); cam.lookAt(...SCENE.camera.target);
      renderer.render(scene, cam);
    }, { SCENE, used, W, H });
    const data = await page.evaluate(() => window.__R.canvas.toDataURL('image/png'));
    fs.writeFileSync(path.join(outDir, SCENE.out || 'scene.png'), Buffer.from(data.split(',')[1], 'base64'));
    console.log('scene done');
    await browser.close();
    return;
  }

  const TEAM = { aegis: [0.18, 0.55, 1.0], vanta: [1.0, 0.22, 0.16] };
  const list = Object.keys(models).filter(n => !NAMES || NAMES.includes(n));
  for (const name of list) {
    for (const view of VIEWS) {
      await page.evaluate(({ m, view, team, W, H, shadow }) => {
        const { renderer, env } = window.__R;
        const scene = new THREE.Scene();
        scene.environment = env;
        scene.add(window.__mesh(m, team));
        const bb = m.bbox;
        const cx = (bb[0] + bb[3]) / 2, cy = (bb[1] + bb[4]) / 2, cz = (bb[2] + bb[5]) / 2;
        const r = 0.5 * Math.hypot(bb[3] - bb[0], bb[4] - bb[1], bb[5] - bb[2]) * 1.02;
        window.__lights(scene, r, shadow);
        const views = { iso: [35, 28], back: [215, 28], side: [90, 12], front: [0, 10], top: [20, 78], low: [320, 18], icon: [32, 24] };
        const [az, el] = views[view] || views.iso;
        const cam = new THREE.PerspectiveCamera(22, W / H, 1, 4000);
        const dist = (r * 1.12) / Math.sin(THREE.MathUtils.degToRad(11));
        const a = THREE.MathUtils.degToRad(az), e = THREE.MathUtils.degToRad(el);
        const tgt = new THREE.Vector3(cx, cy * 0.92, cz);
        cam.position.set(tgt.x + dist * Math.sin(a) * Math.cos(e), tgt.y + dist * Math.sin(e), tgt.z + dist * Math.cos(a) * Math.cos(e));
        cam.lookAt(tgt);
        renderer.render(scene, cam);
      }, { m: models[name], view, team: TEAM[models[name].faction], W, H, shadow: SHADOW });
      const data = await page.evaluate(() => window.__R.canvas.toDataURL('image/png'));
      fs.writeFileSync(path.join(outDir, `${name}__${view}.png`), Buffer.from(data.split(',')[1], 'base64'));
    }
    process.stdout.write(name + ' ');
  }
  console.log('\ndone');
  await browser.close();
})();
