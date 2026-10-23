const fs = require('fs');
const path = require('path');
const vm = require('vm');
const source = fs.readFileSync(path.join(__dirname, '../../scripts/core/run_save_codec.gd'), 'utf8');
const expression = source.match(/const WEB_JSON_CONTENT_VALID := """([\s\S]*?)"""/)[1];
const validate = vm.runInNewContext(expression);
const retained = new Function('source', 'return (' + expression + ')(source);');
const cases = JSON.parse(fs.readFileSync(process.env.BTH_CONTENT_VALIDATION_CORPUS, 'utf8'));
const failures = [];
let fastAccepted = 0, declined = 0;
for (const item of cases) {
    const accepted = validate(item.source);
    if (retained.call(null, item.source) !== accepted) failures.push(item.label + ': direct retained-function argument changed validation');
    if (accepted) fastAccepted++; else declined++;
    if (accepted && !item.expected) failures.push(item.label + ': browser accepted content rejected by Godot');
    if (item.require_fast && !accepted) failures.push(item.label + ': normal supported content declined acceleration');
    if (item.label.startsWith('depth ') && +item.label.slice(6) >= 65 && accepted) failures.push(item.label + ': conservative depth bound not applied');
}
console.log('SAVE_CONTENT_VALIDATION_BROWSER ' + JSON.stringify({cases:cases.length, fastAccepted, declinedToGodot:declined, failures}));
process.exit(failures.length ? 1 : 0);
