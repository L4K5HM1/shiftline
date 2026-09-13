import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {LuauState} from 'luau-web';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const runtime=await LuauState.createAsync({print:console.log});
function files(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?files(path.join(dir,e.name)):[path.join(dir,e.name)]);}
let compiled=0;
try {
 for(const file of files(path.join(root,'src')).filter(f=>f.endsWith('.lua'))){runtime.loadstring(fs.readFileSync(file,'utf8'),path.relative(root,file),true);compiled++;}
 const core=fs.readFileSync(path.join(root,'src/ServerScriptService/ProfileStore.lua'),'utf8');
 const tests=fs.readFileSync(path.join(root,'tests/profile.spec.lua'),'utf8');
 await runtime.loadstring(`local Core = (function()\n${core}\nend)()\n${tests}`,'profile regression tests',true)();
 const jobSource=fs.readFileSync(path.join(root,'src/ServerScriptService/JobMinigameService.server.lua'),'utf8');
 const jobTests=fs.readFileSync(path.join(root,'tests/jobs.spec.lua'),'utf8').replace('__SERVER_SOURCE__',jobSource);
 await runtime.loadstring(`local Core = (function()\n${core}\nend)()\n${jobTests}`,'job handler integration',true)();
 console.log(`Compiled ${compiled} Luau source files. Profile regression suite passed.`);
} finally {runtime.destroy();}
