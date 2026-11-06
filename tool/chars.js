const fs=require('fs');
const src=fs.readFileSync('lib/core/app_strings_generated.dart','utf8');
const lines=src.split('\n');
const keys=[];
for(const line of lines){
  const m=line.match(/^\s*"((?:[^"\\]|\\.)*)"\s*:/);
  if(m){ try{ keys.push(JSON.parse('"'+m[1]+'"')); }catch(e){} }
}
const chars=new Set();
for(const k of keys) for(const ch of k) if(/[\u4e00-\u9fff]/.test(ch)) chars.add(ch);
console.log('keys',keys.length,'chars',chars.size);
console.log([...chars].join(''));
