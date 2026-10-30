import http from 'node:http';
import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
const env={...process.env};try{for(const line of (await readFile('.env.local','utf8')).split('\n')){if(!line.trim()||line.startsWith('#'))continue;const i=line.indexOf('=');if(i>0)env[line.slice(0,i).trim()]=line.slice(i+1).trim();}}catch{}
const worker=(await import(pathToFileURL(process.cwd()+'/dist/server/index.js'))).default;
const server=http.createServer(async(req,res)=>{try{const url='http://localhost:8787'+req.url;const request=new Request(url,{method:req.method,headers:req.headers,...(['GET','HEAD'].includes(req.method)?{}:{body:req,duplex:'half'})});const response=await worker.fetch(request,env);res.writeHead(response.status,Object.fromEntries(response.headers));res.end(Buffer.from(await response.arrayBuffer()));}catch{res.writeHead(500);res.end('Server error');}});
server.listen(8787,'127.0.0.1',()=>console.log('ReelMap: http://localhost:8787'));
