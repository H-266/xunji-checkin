const fs=require('fs');
const b=fs.readFileSync('C:/kernel_good.bin');
const m=Buffer.from('file:///V:/lib/');
let i=0,n=0;
while((i=b.indexOf(m,i))>=0){n++;i+=m.length}
console.log('uris',n);
for(const s of ["import 'dart:async';","import 'package:flutter/material.dart';"]){
 const t=b.indexOf(Buffer.from(s));
 console.log(s,t);
}
