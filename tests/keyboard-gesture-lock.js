// Classic fixture: require('keyboard-gesture-lock').run(); module 2.3.0.
exports.run = function () {
    var BottomSheet = require('ti.bottomsheetcontroller');
    var content = Ti.UI.createView({ backgroundColor: '#ffffff' });
    var field = Ti.UI.createTextArea({ top: 60, left: 20, right: 20, height: 120, borderWidth: 1 });
    var unlock = Ti.UI.createButton({ title: 'Blur / unlock', top: 200 });
    var close = Ti.UI.createButton({ title: 'Close', top: 250 });
    content.add(field); content.add(unlock); content.add(close);
    var sheet = BottomSheet.createBottomSheet({ contentView: content,
        detents: ['medium', 'large'], startDetent: 'medium', prefersGrabberVisible: true });
    field.addEventListener('focus', function () {
        sheet.interactiveGesturesEnabled = false;
        sheet.changeCurrentDetent('large');
    });
    // This fixture unlocks on blur; the chat app waits for keyboard-hidden too.
    field.addEventListener('blur', function () { sheet.interactiveGesturesEnabled = true; });
    unlock.addEventListener('click', function () { field.blur(); });
    close.addEventListener('click', function () { sheet.close(); });
    sheet.open();
};
