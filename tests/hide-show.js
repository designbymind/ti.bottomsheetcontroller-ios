// Copy into a Classic test app's Resources directory with module 2.2.0 installed
// app-locally. Invoke require('hide-show').run(); Results: Documents/hide-show-result.json.
exports.run = async function () {
  const BottomSheet = require('ti.bottomsheetcontroller');
  const win = Ti.UI.createWindow({ backgroundColor: '#eef2f6' });
  const status = Ti.UI.createLabel({ text: 'Running hide/show lifecycle tests…' });
  win.add(status); win.open();
  const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
  let checks = 0;
  const assert = (condition, message) => { if (!condition) throw new Error(message); checks++; };
  async function until(predicate, message) {
    for (let i = 0; i < 100; i++) { if (predicate()) return; await delay(50); }
    throw new Error('Timeout: ' + message);
  }
  function fixture(windowContent, effects) {
    const content = windowContent ? Ti.UI.createWindow({ backgroundColor: 'white' }) : Ti.UI.createView({ backgroundColor: 'white' });
    const field = Ti.UI.createTextField({ value: 'preserved content', top: 30, height: 40, width: 240 });
    content.add(field);
    const config = { contentView: content, detents: [{ identifier: 'bar', height: 96 }, { identifier: 'preview', height: 320 }, 'large'], startDetent: 'preview', dismissible: false };
    if (effects) config.detentEffects = { startHeight: 96, endHeight: 320, views: [{ view: field, from: { scale: 0.5, opacity: 0.5 }, to: { scale: 1, opacity: 1 } }] };
    const sheet = BottomSheet.createBottomSheet(config);
    const count = { open: 0, hide: 0, show: 0, close: 0, dismissing: 0, contentClose: 0 };
    Object.keys(count).filter(key => key !== 'contentClose').forEach(key => sheet.addEventListener(key, () => { count[key]++; }));
    content.addEventListener('close', () => { count.contentClose++; });
    return { sheet, field, count };
  }
  try {
    await delay(600);
    // Both content ownership paths, including paused/resumed effects.
    for (const windowContent of [false, true]) {
      const f = fixture(windowContent, true);
      f.sheet.open({ animated: false });
      f.sheet.hide({ animated: false }); // Before deferred initial presentation.
      await until(() => f.count.hide === 1, 'early hide');
      assert(f.count.open === 1 && f.count.close === 0, 'hide must not close');
      assert(f.count.contentClose === 0, 'hide must not close the content window');
      assert(f.sheet.selectedDetentIdentifier === 'preview', 'hidden selected detent');
      assert(f.sheet.dismissible === false, 'native dismissible property getter');
      f.sheet.dismissible = true;
      assert(f.sheet.dismissible === true, 'native runtime dismissal enabled');
      f.sheet.dismissible = false;
      assert(f.sheet.dismissible === false, 'native runtime dismissal disabled');
      f.sheet.changeCurrentDetent('bar');
      await delay(100);
      assert(f.sheet.selectedDetentIdentifier === 'bar', 'detent update while hidden');
      for (let cycle = 1; cycle <= 8; cycle++) {
        f.sheet.show({ animated: cycle === 1 });
        await until(() => f.count.show === cycle, 'show cycle ' + cycle);
        assert(f.sheet.selectedDetentIdentifier === 'bar', 'restored selected detent');
        assert(f.field.value === 'preserved content', 'retained field value');
        f.sheet.show({ animated: false }); // No-op.
        await delay(50);
        assert(f.count.show === cycle, 'visible show is a no-op');
        f.sheet.hide({ animated: cycle === 1 });
        await until(() => f.count.hide === cycle + 1, 'hide cycle ' + cycle);
        f.sheet.hide({ animated: false }); // No-op.
        await delay(50);
        assert(f.count.hide === cycle + 1, 'hidden hide is a no-op');
      }
      assert(f.count.open === 1 && f.count.close === 0 && f.count.dismissing === 0, 'visibility event isolation');
      f.sheet.close({ animated: true }); // Hidden: must not dismiss host window.
      await until(() => f.count.close === 1, 'hidden close');
      await delay(100);
      assert(f.count.close === 1, 'exactly one final close');
      if (windowContent) assert(f.count.contentClose === 1, 'window closes only on final disposal');
    }
    // An intervening native modal can appear while the sheet remains retained.
    const cardFlow = fixture(false, false);
    cardFlow.sheet.open({ animated: false });
    await until(() => cardFlow.count.open === 1, 'card flow open');
    cardFlow.sheet.hide({ animated: true });
    await until(() => cardFlow.count.hide === 1, 'card flow hide');
    const modalCard = Ti.UI.createWindow({ backgroundColor: '#ccddff' });
    let cardOpened = false, cardClosed = false;
    modalCard.addEventListener('open', () => { cardOpened = true; });
    modalCard.addEventListener('close', () => { cardClosed = true; });
    modalCard.open({ modal: true, animated: true });
    await until(() => cardOpened, 'intervening card open');
    await delay(500);
    assert(cardFlow.count.close === 0, 'card presentation retains hidden sheet');
    modalCard.close({ animated: true });
    await until(() => cardClosed, 'intervening card close');
    await delay(200);
    cardFlow.sheet.show({ animated: true });
    await until(() => cardFlow.count.show === 1, 'restore after card');
    assert(cardFlow.sheet.selectedDetentIdentifier === 'preview', 'card flow detent restored');
    assert(cardFlow.field.value === 'preserved content', 'card flow content retained');
    cardFlow.sheet.close({ animated: false });
    await until(() => cardFlow.count.close === 1, 'card flow final close');
    // show queued while an animated hide is running.
    const rapid = fixture(false, false);
    rapid.sheet.open({ animated: false });
    await until(() => rapid.count.open === 1, 'rapid open');
    rapid.sheet.hide({ animated: true }); rapid.sheet.show({ animated: true });
    await until(() => rapid.count.show === 1, 'queued show');
    assert(rapid.count.hide === 1 && rapid.count.close === 0, 'queued hide/show events');
    rapid.sheet.close({ animated: false });
    await until(() => rapid.count.close === 1, 'visible close');
    // Close during initial open cannot be canceled by later show.
    const earlyClose = fixture(false, false);
    earlyClose.sheet.open({ animated: true });
    earlyClose.sheet.close({ animated: false }); earlyClose.sheet.show({ animated: false });
    await until(() => earlyClose.count.close === 1, 'early close');
    assert(earlyClose.count.show === 0, 'queued close takes priority');
    // Latest pending visibility request wins.
    const latest = fixture(false, false);
    latest.sheet.open({ animated: true });
    latest.sheet.hide({ animated: false }); latest.sheet.show({ animated: false }); latest.sheet.hide({ animated: false });
    await until(() => latest.count.hide === 1, 'latest request');
    assert(latest.count.show === 0, 'latest pending request is hide');
    latest.sheet.close({ animated: false });
    await until(() => latest.count.close === 1, 'latest close');
    const result = { passed: true, checks, cycles: 16 };
    status.text = 'PASS: ' + checks + ' checks, 16 hide/show cycles';
    Ti.Filesystem.getFile(Ti.Filesystem.applicationDataDirectory, 'hide-show-result.json').write(JSON.stringify(result));
    Ti.API.info('HIDE_SHOW_PASS ' + JSON.stringify(result));
  } catch (error) {
    status.text = 'FAIL: ' + error.message;
    Ti.Filesystem.getFile(Ti.Filesystem.applicationDataDirectory, 'hide-show-result.json').write(JSON.stringify({ passed: false, checks, error: error.message }));
    Ti.API.error('HIDE_SHOW_FAIL ' + error.stack);
  }
};
