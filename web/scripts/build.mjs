import {readFile,writeFile,mkdir,rm,copyFile} from 'node:fs/promises';
const html=await readFile('worker/page.html','utf8');
const mapHTML=await readFile('worker/map.html','utf8');
await writeFile('worker/page.js','export const HTML = '+JSON.stringify(html)+';\nexport const MAP_HTML = '+JSON.stringify(mapHTML)+';\n');
const api=await readFile('worker/index.js','utf8');
await rm('dist',{recursive:true,force:true});await mkdir('dist/server',{recursive:true});await mkdir('dist/.openai',{recursive:true});
await writeFile('dist/server/index.js',api.replace("import { HTML, MAP_HTML } from './page.js';",'const HTML = '+JSON.stringify(html)+'; const MAP_HTML = '+JSON.stringify(mapHTML)+';'));
await copyFile('.openai/hosting.json','dist/.openai/hosting.json');
console.log('Built ReelMap worker');
