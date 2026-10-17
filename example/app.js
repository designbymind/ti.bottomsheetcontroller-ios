const BottomSheet = require('ti.bottomsheetcontroller');

const win = Ti.UI.createWindow({
  backgroundColor: '#f5f5f5'
});

const effectsButton = Ti.UI.createButton({ title: 'Open Image Effects', top: '60%' });
win.add(effectsButton);

const openButton = Ti.UI.createButton({
  title: 'Open Bottom Sheet'
});

win.add(openButton);
win.open();

openButton.addEventListener('click', () => {
  const content = Ti.UI.createView({
    backgroundColor: 'transparent'
  });

  const title = Ti.UI.createLabel({
    text: 'Titanium BottomSheetController 2.3',
    top: 28,
    left: 24,
    right: 24,
    textAlign: Ti.UI.TEXT_ALIGNMENT_CENTER,
    font: {
      fontSize: 20,
      fontWeight: 'bold'
    }
  });

  const detail = Ti.UI.createLabel({
    text: 'Drag between bar, preview, and large detents.',
    top: 68,
    left: 24,
    right: 24,
    textAlign: Ti.UI.TEXT_ALIGNMENT_CENTER
  });

  const closeButton = Ti.UI.createButton({
    title: 'Close',
    bottom: 28
  });

  content.add(title);
  content.add(detail);
  content.add(closeButton);

  const sheet = BottomSheet.createBottomSheet({
    contentView: content,
    detents: [
      { identifier: 'bar', height: 96 },
      { identifier: 'preview', height: 320 },
      'large'
    ],
    startDetent: 'bar',
    dismissible: false,
    largestUndimmedDetentIdentifier: 'bar',
    prefersGrabberVisible: true
  });

  sheet.addEventListener('open', () => {
    Ti.API.info('Bottom sheet opened');
  });

  sheet.addEventListener('detentChange', e => {
    Ti.API.info('Selected detent: ' + e.selectedDetentIdentifier);
  });

  sheet.addEventListener('close', () => {
    Ti.API.info('Bottom sheet closed');
  });

  closeButton.addEventListener('click', () => {
    sheet.close({ animated: true });
  });

  sheet.open({ animated: true });
});

// Separate opt-in example; the original button still exercises an ordinary sheet.
effectsButton.addEventListener('click', () => {
  const size = Math.min(Ti.Platform.displayCaps.platformWidth - 48, 320);
  const content = Ti.UI.createView({ backgroundColor: 'transparent' });
  const cover = Ti.UI.createImageView({
    image: 'cover.png', width: size, height: size, top: 28,
    touchEnabled: false
  });
  content.add(cover);
  const close = Ti.UI.createButton({ title: 'Close', width: 70, height: 32 });
  const sheet = BottomSheet.createBottomSheet({
    contentView: content, closeButton: close,
    detents: [{ identifier: 'bar', height: 96 }, { identifier: 'cover', height: 420 }, 'large'],
    startDetent: 'bar', dismissible: false, prefersGrabberVisible: true,
    largestUndimmedDetentIdentifier: 'cover',
    detentEffects: {
      startHeight: 96, endHeight: 420,
      views: [{
        view: cover,
        // Scaling uses the view center. Move the small thumbnail back toward the top.
        from: { scale: 64 / size, opacity: 0.6, translationY: -(size - 64) / 2, cornerRadius: 64 },
        to: { scale: 1, opacity: 1, translationY: 0, cornerRadius: 0 }
      }]
    }
  });
  close.addEventListener('click', () => sheet.close({ animated: true }));
  sheet.open({ animated: true });
});

// Reusable content example. The overlay stands in for a map annotation card.
let reusableSheet = null;
const reuseButton = Ti.UI.createButton({ title: 'Open Reusable Sheet', top: '75%' });
const card = Ti.UI.createView({ width: 300, height: 220, backgroundColor: '#ffffff', borderRadius: 18, visible: false });
const restore = Ti.UI.createButton({ title: 'Close Card and Restore Sheet' });
card.add(restore);
win.add(reuseButton);
win.add(card);
reuseButton.addEventListener('click', () => {
  if (reusableSheet) return;
  const content = Ti.UI.createView({ backgroundColor: 'transparent' });
  const field = Ti.UI.createTextField({ top: 36, left: 24, right: 24, height: 44, value: 'This content stays in memory' });
  const hide = Ti.UI.createButton({ title: 'Hide Sheet and Show Card', top: 104 });
  const close = Ti.UI.createButton({ title: 'Close Permanently', top: 156 });
  content.add(field); content.add(hide); content.add(close);
  reusableSheet = BottomSheet.createBottomSheet({
    contentView: content, detents: [{ identifier: 'card', height: 250 }, 'large'],
    startDetent: 'card', dismissible: false, prefersGrabberVisible: true
  });
  reusableSheet.addEventListener('hide', () => { card.visible = true; });
  reusableSheet.addEventListener('close', () => { reusableSheet = null; card.visible = false; });
  hide.addEventListener('click', () => { field.blur(); reusableSheet.hide({ animated: true }); });
  close.addEventListener('click', () => reusableSheet.close({ animated: true }));
  reusableSheet.open({ animated: true });
});
restore.addEventListener('click', () => {
  card.visible = false;
  if (reusableSheet) reusableSheet.show({ animated: true });
});

// Full-screen dimming works with a stationary or scaled background.
[false, true].forEach(scales => {
  const button = Ti.UI.createButton({
    title: scales ? 'Full-screen + Scale and Dim' : 'Full-screen + Dim',
    top: scales ? '28%' : '18%'
  });
  win.add(button);
  button.addEventListener('click', () => {
    const content = Ti.UI.createView({ backgroundColor: '#92603e' });
    const rows = Array.from({ length: 80 }, (_, index) => ({ title: 'Row ' + (index + 1), color: 'white', height: 54 }));
    const table = Ti.UI.createTableView({ top: 90, bottom: 80, data: rows, backgroundColor: 'transparent', separatorColor: '#b28a6e' });
    const hide = Ti.UI.createButton({ title: 'Hide and Restore', bottom: 22, color: 'white' });
    const close = Ti.UI.createButton({ title: 'Close', width: 70, height: 32, color: 'white' });
    content.add(table); content.add(hide);
    const sheet = BottomSheet.createBottomSheet({
      presentationMode: 'fullScreen', contentView: content, scrollView: table,
      backgroundColor: '#92603e', closeButton: close,
      scalesPresentingView: scales,
      fadesPresentingView: true,
      presentingViewScale: 0.9,
      presentingViewCornerRadius: 50,
      fullScreenCornerRadius: 30,
      dismissible: true
    });
    sheet.addEventListener('hide', () => setTimeout(() => sheet.show({ animated: true }), 800));
    hide.addEventListener('click', () => sheet.hide({ animated: true }));
    close.addEventListener('click', () => sheet.close({ animated: true }));
    sheet.open({ animated: true });
  });
});
