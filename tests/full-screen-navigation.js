// Classic Titanium regression: require('full-screen-navigation').run().
// Exercises the lazy NavigationWindow hierarchy used by AlloyTestApp's chat.
exports.run = async function () {
  const BottomSheet = require('ti.bottomsheetcontroller');
  const presenter = Ti.UI.createWindow({ backgroundColor: '#ffffff' });
  presenter.open();
  const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
  let checks = 0;
  const assert = (condition, message) => { if (!condition) throw new Error(message); checks++; };
  async function until(predicate, message) {
    for (let i = 0; i < 100; i++) { if (predicate()) return; await delay(50); }
    throw new Error('Timeout: ' + message);
  }
  function fixture(mode, invalidScroll) {
    const chat = Ti.UI.createWindow({ title: 'Navigation regression', backgroundColor: '#ffffff' });
    const table = Ti.UI.createTableView({ data: [{ title: 'Message', height: 72 }] });
    chat.add(table);
    const navigation = Ti.UI.createNavigationWindow({ window: chat });
    const options = { contentView: navigation, presentationMode: mode, dismissible: true };
    if (mode === 'fullScreen') options.scrollView = invalidScroll ? Ti.UI.createTableView({}) : table;
    else { options.detents = ['medium', 'large']; options.startDetent = 'medium'; }
    const sheet = BottomSheet.createBottomSheet(options);
    const events = { open: 0, close: 0, hide: 0, show: 0, error: null };
    ['open', 'close', 'hide', 'show'].forEach(name => sheet.addEventListener(name, event => {
      events[name]++;
      if (event.error) events.error = event.error;
    }));
    return { sheet, events };
  }
  try {
    await delay(500);
    for (const mode of ['fullScreen', 'fullScreen', 'native']) {
      const f = fixture(mode, false);
      f.sheet.open({ animated: false });
      await until(() => f.events.open || f.events.close, mode + ' open');
      assert(f.events.open === 1 && !f.events.error, mode + ' accepts nested table');
      f.sheet.interactiveGesturesEnabled = false;
      assert(f.sheet.interactiveGesturesEnabled === false, 'gesture lock');
      f.sheet.interactiveGesturesEnabled = true;
      assert(f.sheet.interactiveGesturesEnabled === true, 'gesture unlock');
      f.sheet.hide({ animated: false });
      await until(() => f.events.hide === 1, mode + ' hide');
      f.sheet.show({ animated: false });
      await until(() => f.events.show === 1, mode + ' show');
      assert(f.events.close === 0, 'hide/show retains navigation');
      f.sheet.close({ animated: false });
      await until(() => f.events.close === 1, mode + ' close');
      assert(!f.events.error, mode + ' clean close');
      await delay(150);
    }
    const invalid = fixture('fullScreen', true);
    invalid.sheet.open({ animated: false });
    await until(() => invalid.events.close === 1, 'unrelated table rejected');
    assert(invalid.events.open === 0 && !!invalid.events.error, 'unrelated table still rejected');
    const result = { passed: true, checks };
    Ti.Filesystem.getFile(Ti.Filesystem.applicationDataDirectory, 'full-screen-navigation-result.json').write(JSON.stringify(result));
    Ti.API.info('FULL_SCREEN_NAVIGATION_PASS ' + JSON.stringify(result));
  } catch (error) {
    Ti.Filesystem.getFile(Ti.Filesystem.applicationDataDirectory, 'full-screen-navigation-result.json').write(JSON.stringify({ passed: false, checks, error: error.message }));
    Ti.API.error(error.stack);
  }
};
