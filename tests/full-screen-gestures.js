// Manual gesture harness for Classic apps with app-local module 2.2.0.
// Invoke require('full-screen-gestures').run(); latest counts: Documents/full-screen-gesture-result.json.
exports.run = function () {
  const BottomSheet = require('ti.bottomsheetcontroller');
  const win = Ti.UI.createWindow({ backgroundColor: '#e6eef7' });
  win.open();
  [['table', true], ['list', true], ['scroll', true], ['plain', true], ['table', false]].forEach(([type, scales], index) => {
    const open = Ti.UI.createButton({ title: type + (scales ? ', scaled' : ', stationary'), top: 130 + index * 60 });
    win.add(open);
    open.addEventListener('click', () => {
      const content = Ti.UI.createView({ backgroundColor: '#92603e' });
      let scroll;
      if (type === 'table') scroll = Ti.UI.createTableView({ top: 110, bottom: 70, backgroundColor: 'transparent', data: Array.from({ length: 80 }, (_, i) => ({ title: 'Row ' + (i + 1), color: 'white', height: 54 })) });
      if (type === 'list') scroll = Ti.UI.createListView({ top: 110, bottom: 70, sections: [Ti.UI.createListSection({ items: Array.from({ length: 80 }, (_, i) => ({ properties: { title: 'Row ' + (i + 1), height: 54 } })) })] });
      if (type === 'scroll') {
        scroll = Ti.UI.createScrollView({ top: 110, bottom: 70, contentHeight: 2000 });
        scroll.add(Ti.UI.createLabel({ text: 'Drag here to scroll, then pull down at the top', top: 30, color: 'white' }));
      }
      if (scroll) content.add(scroll);
      else content.add(Ti.UI.createLabel({ text: 'Plain full-screen content', color: 'white', top: 130 }));
      const close = Ti.UI.createButton({ title: 'Close', width: 70, height: 32, color: 'white' });
      const lock = Ti.UI.createButton({ title: 'Lock drag', top: 70, left: 12, width: 120, height: 32, color: 'white' });
      content.add(lock);
      const sheet = BottomSheet.createBottomSheet({ presentationMode: 'fullScreen', contentView: content, scrollView: scroll, closeButton: close, scalesPresentingView: scales, backgroundColor: '#92603e' });
      const count = { type, scales, open: 0, dismissing: 0, close: 0 };
      const write = () => Ti.Filesystem.getFile(Ti.Filesystem.applicationDataDirectory, 'full-screen-gesture-result.json').write(JSON.stringify(count));
      ['open', 'dismissing', 'close'].forEach(event => sheet.addEventListener(event, () => { count[event]++; write(); }));
      close.addEventListener('click', () => sheet.close({ animated: true }));
      lock.addEventListener('click', () => { sheet.dismissible = !sheet.dismissible; lock.title = sheet.dismissible ? 'Lock drag' : 'Unlock drag'; });
      sheet.open({ animated: true });
    });
  });
  return win;
};
