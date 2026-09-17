from pathlib import Path
import wave, numpy as np, hashlib, json, shutil
root=Path(__file__).resolve().parents[2]; source=root/'sfx'; target=root/'assets/audio/sfx'
def write(p,s):
    t=root/p;t.parent.mkdir(parents=True,exist_ok=True);t.write_text(s,encoding='utf-8',newline='\n')
write('sfx/.gdignore','')
ignore=(root/'.gitignore').read_text()
if '\n/sfx/\n' not in ignore:write('.gitignore',ignore+'\n# User supplied audio masters; working copies live under assets/audio/sfx.\n/sfx/\n')
catalog=[]
for p in sorted(source.rglob('*')):
    if p.suffix not in ['.wav','.ogg','.mp3']:continue
    rel=p.relative_to(source).as_posix(); item={'source':'sfx/'+rel,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'license':'Aportado por el usuario; autor y permiso de distribución pendientes','status':'reserved','working_copy':None}
    if p.suffix in ['.ogg','.mp3']:
        dest=target/p.relative_to(source);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest)
        item['working_copy']=dest.relative_to(root).as_posix()
        if rel.startswith(('door/opening/','door/closing/','wardrobe/')): item['status']='integrated'
    if p.suffix=='.wav':
        with wave.open(str(p),'rb') as w:
            rate=w.getframerate(); ch=w.getnchannels(); width=w.getsampwidth(); frames=w.getnframes(); raw=w.readframes(frames)
        if width==3:
            b=np.frombuffer(raw,np.uint8).reshape(-1,3).astype(np.int32)
            ints=b[:,0]|(b[:,1]<<8)|(b[:,2]<<16);ints=(ints^0x800000)-0x800000
            samples=ints.astype(np.float32)/(2**23)
        else:samples=np.frombuffer(raw,'<i2').astype(np.float32)/32768
        samples=samples.reshape(-1,ch)
        item.update(seconds=frames/rate,channels=ch,sample_rate=rate,bits=width*8,peak=float(abs(samples).max()),rms=float(np.sqrt(np.mean(samples*samples))))
        if 'only-ambience/' in rel or 'dark presence' in rel:
            mono='dark presence' in rel
            if mono:samples=samples.mean(axis=1,keepdims=True)
            # Anti-aliasing before decimation, preserving the source master unchanged.
            factor=2; n=np.arange(-31,32); kernel=np.sinc(n*0.45)*np.hamming(63);kernel/=kernel.sum()
            samples=np.stack([np.convolve(samples[:,c],kernel,mode='same')[::factor] for c in range(samples.shape[1])],axis=1)
            out_rate=rate//factor
            # Overlap tail and head to eliminate a hard seam; output starts after the overlap.
            overlap=int(out_rate*1.0)
            ramp=np.linspace(0,1,overlap,endpoint=False)[:,None]
            seam=samples[-overlap:]*(1-ramp)+samples[:overlap]*ramp
            samples=np.concatenate([samples[overlap:-overlap],seam])
            gain=min(1.0,0.8/max(float(abs(samples).max()),0.00001));samples*=gain
            dest=target/('presence/locust_presence.wav' if mono else 'ambience/dark_hotel.wav');dest.parent.mkdir(parents=True,exist_ok=True)
            with wave.open(str(dest),'wb') as w:
                w.setnchannels(samples.shape[1]);w.setsampwidth(2);w.setframerate(out_rate);w.writeframes(np.clip(samples*32767,-32768,32767).astype('<i2').tobytes())
            item.update(status='integrated',working_copy=dest.relative_to(root).as_posix(),processing={'mono':mono,'sample_rate':out_rate,'bits':16,'loop_crossfade_seconds':1,'gain':gain,'seconds':len(samples)/out_rate})
    if 'hard-' in rel: item['status']='integrated'
    catalog.append(item)
write('docs/assets/sfx_inventory.json',json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
print('Catalogued',len(catalog),'files;',sum(x['status']=='integrated' for x in catalog),'integrated candidates.')
