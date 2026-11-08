"""Gera a fotografia ILUSTRATIVA usada nos mockups: textura de pele neutra, procedural, sem lesão.
Não é uma fotografia real nem médica. Saída: photo-placeholder.jpg (4:3) e photo-portrait.jpg (3:4)."""
import numpy as np
from PIL import Image, ImageFilter
rng=np.random.default_rng(7); W,H=1200,900
def noise(scale):
    small=rng.random((H//scale+2,W//scale+2))
    im=Image.fromarray((small*255).astype(np.uint8)).resize((W+scale*2,H+scale*2),Image.BICUBIC).crop((0,0,W,H))
    return np.asarray(im,dtype=np.float32)/255
base=np.array([205,160,130],np.float32)
low=noise(220)-0.5; mid=noise(60)-0.5; fine=noise(6)-0.5; pores=(rng.random((H,W))>0.995).astype(np.float32)
pores=np.asarray(Image.fromarray((pores*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.4)),np.float32)/255
yy,xx=np.mgrid[0:H,0:W]; light=1.05-0.18*((xx/W-0.35)**2+(yy/H-0.3)**2)
img=np.zeros((H,W,3),np.float32)
for c,(k1,k2) in enumerate(((26,10),(20,8),(18,7))):
    img[...,c]=base[c]+low*k1*2+mid*k2+fine*6-pores*25
img*=light[...,None]; img[...,0]+=6*np.clip(low*2,0,1)
out=Image.fromarray(np.clip(img,0,255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))
out.save("photo-placeholder.jpg",quality=90); out.rotate(90,expand=True).save("photo-portrait.jpg",quality=90)
