"""Continuous illustrated intro from five fixed ImageGen drawings.

One room, two character cutouts, localized blink art, smooth joint motion,
planted-foot walking and shared poses at every clip/reading-loop boundary.
Requires numpy, opencv-python-headless and FFmpeg; not a runtime dependency.
"""
from pathlib import Path
import argparse,hashlib,json,math,subprocess
import cv2
import numpy as np
cv2.setNumThreads(3)
cv2.setRNGSeed(0)
W,H=1920,1080
SPECS=[('1789650644963',121,30),('1789649201942',125,30),
       ('1789650878847',121,30),('1789649329293',121,30)]

def ease(x):
    x=np.clip(x,0.,1.)
    return x*x*x*(x*(x*6.-15.)+10.)

def blink(p,center,width=.075):
    return float(ease(1.-abs(p-center)/width))

def foot_path(p,raw,intervals,fraction):
    start=np.array([1200.+raw[0]*.40,310.+raw[1]*.40],np.float32)
    end=np.array([1030.+raw[0]*.46,280.+raw[1]*.46],np.float32)
    progress=0.;lift=0.
    for (a,b),amount in zip(intervals,[fraction,1.-fraction]):
        u=float(np.clip((p-a)/(b-a),0.,1.))
        progress+=amount*float(ease(u))
        if 0.<u<1.:lift=16.*math.sin(math.pi*u)**2
    ground=start+(end-start)*progress
    point=ground.copy();point[1]-=lift
    return point,ground,lift

class Actor:
    def __init__(self,root,name):
        self.name=name
        raw=cv2.imread(str(root/(name+'.png')),cv2.IMREAD_UNCHANGED)
        assert raw is not None and raw.shape[2]==4
        self.size=raw.shape[1::-1]
        opened=raw.astype(np.float32)/255.
        opened[:,:,3]=np.clip(opened[:,:,3]*255./253.,0.,1.)
        x,y,x2,y2=(200,10,850,650) if name=='carolina' else (280,30,750,420)
        ref=raw[y:y2,x:x2,:3]
        painted=cv2.imread(str(root/(name+'-blink.png')),cv2.IMREAD_UNCHANGED)
        painted=cv2.resize(painted,(x2-x,y2-y),interpolation=cv2.INTER_AREA)
        sift=cv2.SIFT_create(2400)
        k1,d1=sift.detectAndCompute(cv2.cvtColor(painted[:,:,:3],cv2.COLOR_BGR2GRAY),None)
        k2,d2=sift.detectAndCompute(cv2.cvtColor(ref,cv2.COLOR_BGR2GRAY),None)
        good=[a for a,b in cv2.BFMatcher().knnMatch(d1,d2,k=2) if a.distance<.72*b.distance]
        assert len(good)>=12,(name,'blink registration')
        m,inliers=cv2.estimateAffinePartial2D(np.float32([k1[a.queryIdx].pt for a in good]),
            np.float32([k2[a.trainIdx].pt for a in good]),method=cv2.RANSAC,ransacReprojThreshold=2.)
        assert m is not None
        aligned=cv2.warpAffine(painted[:,:,:3],m,(x2-x,y2-y),flags=cv2.INTER_CUBIC,
            borderMode=cv2.BORDER_REFLECT_101).astype(np.float32)/255.
        closed=opened.copy();closed[y:y2,x:x2,:3]=aligned
        mask=np.zeros(raw.shape[:2],np.float32)
        eyes=[(547,357,50,32),(646,380,39,28)] if name=='carolina' else [(406,237,32,29),(495,234,38,31)]
        for ex,ey,rx,ry in eyes:cv2.ellipse(mask,(ex,ey),(rx,ry),0,0,360,1.,-1)
        mask=cv2.GaussianBlur(mask,(0,0),4.)
        self.delta=(closed[:,:,:3]-opened[:,:,:3])*mask[:,:,None]*opened[:,:,3:4]
        self.opened=opened;self.opened[:,:,:3]*=self.opened[:,:,3:4]
        self.cache={}
        print('BLINK REGISTER:',name,len(good),'matches',int(inliers.sum()),'inliers',flush=True)

    def textures(self,sw,sh):
        key=(sw,sh)
        if key not in self.cache:
            # Adult scale is constant. Cache each child's small scale once too.
            self.cache[key]=(cv2.resize(self.opened,key,interpolation=cv2.INTER_AREA),
                             cv2.resize(self.delta,key,interpolation=cv2.INTER_AREA))
        return self.cache[key]

    def render(self,frame,stage,p,blanket,landmarks):
        adult=self.name=='carolina';b=(1.-math.cos(2.*math.pi*p))*.5
        if adult:
            closed=1.-float(ease((p-.17)/.27)) if stage==0 else blink(p,.58)
            scale=.42;x=300.;y=245.
            rest=1.-float(ease((p-.08)/.82)) if stage==0 else 0.
            angle=-27.*rest+.65*b;y+=32.*rest
        else:
            closed=blink(p,.35)
            travel=float(ease(p)) if stage==2 else (1. if stage==3 else 0.)
            scale=.40+.06*travel;x=1200.-170.*travel;y=310.-30.*travel
            angle=-.15*b
        sw,sh=round(self.size[0]*scale),round(self.size[1]*scale)
        base,eye_delta=self.textures(sw,sh)
        rgba=base.copy();rgba[:,:,:3]+=eye_delta*closed
        yy,xx=np.mgrid[0:sh,0:sw].astype(np.float32);nx=xx/sw;ny=yy/sh
        dx=np.zeros((sh,sw),np.float32);dy=np.zeros((sh,sw),np.float32)
        feet=[]
        if adult:
            dy-=1.8*b*np.exp(-((ny-.53)/.23)**2)
            head=1.-ease((ny-.33)/.12);dx+=.85*b*head;dy+=.5*b*head
            pivot=(sw*.51,sh*.62)
        else:
            dy-=1.3*b*np.exp(-((ny-.36)/.20)**2)
            if stage==2:
                env=math.sin(math.pi*p)**2;phase=4.*math.pi*p
                side=ease((nx-.49)/.12);legs=ease((ny-.50)/.43);offsets=[]
                for raw,intervals,fraction in [((470,1450),[(0.,.22),(.52,.78)],.35),
                    ((675,1505),[(.23,.49),(.76,1.)],.50)]:
                    point,ground,lift=foot_path(p,raw,intervals,fraction)
                    offsets.append(point-np.array([x+raw[0]*scale,y+raw[1]*scale]))
                    feet.append((ground,lift))
                dx+=legs*((1.-side)*offsets[0][0]+side*offsets[1][0])
                dy+=legs*((1.-side)*offsets[0][1]+side*offsets[1][1])
                dy-=1.7*env*(1.-math.cos(2.*phase))*(1.-legs);angle=0.
            pivot=(sw*.52,sh*.97)
        rgba=cv2.remap(rgba,xx-dx,yy-dy,cv2.INTER_CUBIC,borderMode=cv2.BORDER_CONSTANT)
        m=cv2.getRotationMatrix2D(pivot,-angle,1.);m[:,2]+=[x,y]
        corners=np.float32([[0,0,1],[sw,0,1],[sw,sh,1],[0,sh,1]])@m.T
        x0,y0=np.maximum(0,np.floor(corners.min(axis=0)-3).astype(int))
        x1,y1=np.minimum([W,H],np.ceil(corners.max(axis=0)+3).astype(int))
        local=m.copy();local[:,2]-=[x0,y0]
        layer=cv2.warpAffine(rgba,local,(x1-x0,y1-y0),flags=cv2.INTER_CUBIC,borderMode=cv2.BORDER_CONSTANT)
        alpha=np.clip(layer[:,:,3:4],0.,1.);color=layer[:,:,:3]
        if adult:
            visible=1.-blanket[y0:y1,x0:x1,None];alpha*=visible;color*=visible
        else:
            if stage!=2:feet=[(m@np.array([rx*scale,ry*scale,1.]),0.) for rx,ry in [(470,1450),(675,1505)]]
            for (fx,fy),lift in feet:
                a,c=max(0,int(fx-90)),min(W,int(fx+90));d,e=max(0,int(fy-24)),min(H,int(fy+24))
                shadow=np.exp(-(((np.arange(a,c)[None,:]-fx)/36.)**2+
                    ((np.arange(d,e)[:,None]-fy)/6.)**2)).astype(np.float32)
                frame[d:e,a:c]*=1.-shadow[:,:,None]*(.19-.004*lift)
            landmarks['feet']=[[float(a),float(b)] for (a,b),_ in feet]
        frame[y0:y1,x0:x1]=color+frame[y0:y1,x0:x1]*(1.-alpha)
        head=m@np.array([sw*.54,sh*(.24 if adult else .16),1.])
        landmarks[self.name]=[float(v) for v in head]

class Scene:
    def __init__(self,assets):
        self.background=cv2.resize(cv2.imread(str(assets/'room.png')),(W,H),interpolation=cv2.INTER_CUBIC).astype(np.float32)/255.
        self.actors=[Actor(assets,'carolina'),Actor(assets,'darina')]
        self.blanket=np.zeros((H,W),np.float32)
        edge=np.array([[0,628],[90,603],[190,581],[290,571],[382,564],[460,549],
            [525,552],[580,560],[630,553],[683,563],[735,579],[795,608],[863,658],
            [947,737],[1048,850],[1168,1080],[0,1080]],np.int32)
        cv2.fillPoly(self.blanket,[edge],1.);self.blanket=cv2.GaussianBlur(self.blanket,(0,0),1.2)

    def frame(self,stage,p):
        frame=self.background.copy();landmarks={}
        for actor in self.actors:actor.render(frame,stage,p,self.blanket,landmarks)
        camera=1.+.010*(float(ease(p)) if stage==0 else 1.)
        if stage==2:camera+=.008*float(ease(p))
        if stage==3:camera+=.008
        m=cv2.getRotationMatrix2D((W*.52,H*.46),0.,camera)
        frame=cv2.warpAffine(frame,m,(W,H),flags=cv2.INTER_CUBIC,borderMode=cv2.BORDER_REFLECT_101)
        return np.clip(frame*255.+.5,0,255).astype(np.uint8),landmarks

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--assets',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--preview',action='store_true');args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=True);scene=Scene(args.assets)
    if args.preview:
        for stage,p in [(0,0.),(0,.5),(0,1.),(1,.58),(2,.5),(2,1.),(3,.35)]:
            image,_=scene.frame(stage,p);cv2.imwrite(str(args.output/f'stage-{stage}-{p:.2f}.png'),image)
        return
    report=[];last=None
    for stage,(name,count,fps) in enumerate(SPECS):
        target=args.output/(name+'.mp4')
        encoder=subprocess.Popen(['ffmpeg','-v','error','-y','-f','rawvideo','-pix_fmt','bgr24',
            '-s',f'{W}x{H}','-r',str(fps),'-i','pipe:0','-an','-c:v','libx264','-preset','fast',
            '-crf','17','-pix_fmt','yuv420p','-threads','3','-movflags','+faststart',str(target)],stdin=subprocess.PIPE)
        changes=[];positions=[]
        for i in range(count):
            image,joints=scene.frame(stage,i/(count-1));small=cv2.resize(image,(320,180),interpolation=cv2.INTER_AREA).astype(np.float32)
            if i==0:first=small.copy();boundary=float(np.abs(small-last).mean()) if last is not None else 0.
            else:changes.append(float(np.abs(small-last).mean()))
            last=small;positions.append(joints);encoder.stdin.write(image.tobytes())
        encoder.stdin.close();assert encoder.wait()==0
        loop=float(np.abs(first-last).mean());assert boundary<.02,(stage,'boundary',boundary)
        if stage in [1,3]:assert loop<.02,(stage,'loop',loop)
        report.append({'source':target.name,'frames':count,'fps':fps,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
            'boundary_pixel_delta':boundary,'loop_pixel_delta':loop,'median_frame_delta':float(np.median(changes)),
            'max_frame_delta':max(changes),'landmarks':positions})
        print('CONTINUOUS INTRO:',target.name,'seam',boundary,'loop',loop,flush=True)
    (args.output/'animation-report.json').write_text(json.dumps(report,indent=2)+'\n')

if __name__=='__main__':main()
