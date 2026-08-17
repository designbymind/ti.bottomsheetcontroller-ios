const BottomSheet = require('ti.bottomsheetcontroller');

const win = Ti.UI.createWindow({
  backgroundColor: '#f5f5f5'
});

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
    text: 'Titanium BottomSheetController 2.0',
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
