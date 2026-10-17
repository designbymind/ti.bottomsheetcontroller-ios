// Classic test app: app-local module 2.2.0, then require('full-screen').run().
// Results are written to Documents/full-screen-result.json.
exports.run = async function () {
  const BottomSheet = require('ti.bottomsheetcontroller');
  const win = Ti.UI.createWindow({ backgroundColor: '#d7e9f5' });
  const status = Ti.UI.createLabel({ text: 'Full-screen lifecycle tests…' });
  win.add(status); win.open();
  const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
  let checks = 0;
  const assert = (value, message) => { if (!value) throw new Error(message); checks++; };
  async function until(predicate, message) {
    for (let i = 0; i < 120; i++) { if (predicate()) return; await delay(50); }
    throw new Error('Timeout: ' + message);
  }
  function fixture(scales, type, windowContent) {
    const content = windowContent ? Ti.UI.createWindow({ backgroundColor: '#92603e' }) : Ti.UI.createView({ backgroundColor: '#92603e' });
    const field = Ti.UI.createTextField({ value: 'retained full-screen content', top: 90, height: 40, width: 270 });
    content.add(field);
    let scroll;
    if (type === 'table') scroll = Ti.UI.createTableView({ top: 150, bottom: 30, data: Array.from({ length: 50 }, (_, i) => ({ title: 'Row ' + i, height: 50 })) });
    if (type === 'list') scroll = Ti.UI.createListView({ top: 150, bottom: 30, sections: [Ti.UI.createListSection({ items: Array.from({ length: 50 }, (_, i) => ({ properties: { title: 'Row ' + i, height: 50 } })) })] });
    if (type === 'scroll') {
      scroll = Ti.UI.createScrollView({ top: 150, bottom: 30, contentHeight: 2000 });
      scroll.add(Ti.UI.createLabel({ text: 'Scrollable content', top: 20 }));
    }
    if (scroll) content.add(scroll);
    const sheet = BottomSheet.createBottomSheet({ presentationMode: 'fullScreen', contentView: content, scrollView: scroll, scalesPresentingView: scales, dismissible: false });
    const count = { open: 0, hide: 0, show: 0, close: 0, contentClose: 0 };
    ['open', 'hide', 'show', 'close'].forEach(event => sheet.addEventListener(event, () => { count[event]++; }));
    content.addEventListener('close', () => { count.contentClose++; });
    return { sheet, field, count };
  }
  try {
    await delay(600);
    for (const scales of [false, true]) {
      for (const type of ['none', 'table', 'list', 'scroll']) {
        const f = fixture(scales, type, type === 'none');
        f.sheet.open({ animated: true });
        f.sheet.hide({ animated: false }); // Queued behind initial opening.
        await until(() => f.count.hide === 1, 'initial hide ' + type);
        assert(f.count.open === 1 && f.count.close === 0 && f.count.contentClose === 0, 'hide retains content');
        assert(f.sheet.selectedDetentIdentifier === 'none', 'full-screen has no detents');
        assert(f.sheet.dismissible === false, 'dismissible property getter');
        f.sheet.dismissible = true;
        assert(f.sheet.dismissible === true, 'dismissible enabled at runtime');
        f.sheet.dismissible = false;
        assert(f.sheet.dismissible === false, 'dismissible disabled at runtime');
        for (let cycle = 1; cycle <= 3; cycle++) {
          f.sheet.show({ animated: cycle === 1 });
          await until(() => f.count.show === cycle, 'show ' + type);
          assert(f.field.value === 'retained full-screen content', 'retained value');
          f.sheet.hide({ animated: cycle === 1 });
          await until(() => f.count.hide === cycle + 1, 'hide ' + type);
        }
        f.sheet.close({ animated: true });
        await until(() => f.count.close === 1, 'hidden close ' + type);
        assert(f.count.open === 1 && f.count.close === 1, 'single open/final close');
      }
    }
    const rapid = fixture(true, 'table', false);
    rapid.sheet.open({ animated: false });
    await until(() => rapid.count.open === 1, 'rapid open');
    rapid.sheet.hide({ animated: true }); rapid.sheet.show({ animated: true });
    await until(() => rapid.count.show === 1, 'show during hide');
    rapid.sheet.close({ animated: true });
    await until(() => rapid.count.close === 1, 'visible close');
    assert(rapid.count.hide === 1 && rapid.count.show === 1, 'serialized visibility');
    const early = fixture(true, 'none', false);
    early.sheet.open({ animated: true }); early.sheet.close({ animated: false }); early.sheet.show({ animated: true });
    await until(() => early.count.close === 1, 'early close');
    assert(early.count.show === 0, 'close cannot be canceled');
    const result = { passed: true, checks, cycles: 24, styles: 2, scrollingTypes: 3 };
    status.text = 'PASS: full-screen ' + checks + ' checks, 24 cycles';
    Ti.Filesystem.getFile(Ti.Filesystem.applicationDataDirectory, 'full-screen-result.json').write(JSON.stringify(result));
    Ti.API.info('FULL_SCREEN_PASS ' + JSON.stringify(result));
  } catch (error) {
    status.text = 'FAIL: ' + error.message;
    Ti.Filesystem.getFile(Ti.Filesystem.applicationDataDirectory, 'full-screen-result.json').write(JSON.stringify({ passed: false, checks, error: error.message }));
    Ti.API.error(error.stack);
  }
};
