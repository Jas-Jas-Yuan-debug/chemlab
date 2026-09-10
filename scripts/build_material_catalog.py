#!/usr/bin/env python3
"""Screenshot-requested solid packages; chemical operational support is separate."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
# name; composition/formula; appearance. Different packages share chemical identity.
lines='''氧化铜;CuO;black
铁粉;Fe;gray
氯酸钾;KClO3;white
高锰酸钾;KMnO4;purple
二氧化锰;MnO2;black
钠;Na;silver
碳酸钠;Na2CO3;white
过氧化钠;Na2O2;yellow
蔗糖;C12H22O11;white
铁钉;Fe;gray
铝热剂;Al + Fe2O3;gray
沙子;混合物（主要为 SiO2）;sand
银;Ag;silver
硫化银;Ag2S;black
硫酸银;Ag2SO4;white
氯化银;AgCl;white
碘化银;AgI;yellow
硝酸银;AgNO3;white
铝粉;Al;silver
氧化铝;Al2O3;white
硫化铝;Al2S3;white
硫酸铝;Al2(SO4)3;white
溴化铝;AlBr3;white
氯化铝;AlCl3;white
硝酸铝;Al(NO3)3;white
氢氧化铝;Al(OH)3;white
氯化钡;BaCl2;white
碳酸钡;BaCO3;white
硝酸钡;Ba(NO3)2;white
氧化钡;BaO;white
氢氧化钡;Ba(OH)2;white
硫酸钡;BaSO4;white
木炭;C（含杂质）;black
氯化钙;CaCl2;white
碳酸钙;CaCO3;white
硝酸钙;Ca(NO3)2;white
氧化钙;CaO;white
氢氧化钙;Ca(OH)2;white
硫酸钙;CaSO4;white
铜粉;Cu;copper
硫化亚铜;Cu2S;black
氯化铜;CuCl2;brown
硝酸铜;Cu(NO3)2;blue
氢氧化铜;Cu(OH)2;blue
五水合硫酸铜;CuSO4·5H2O;blue
硫酸铜;CuSO4;white
氧化铁;Fe2O3;red
硫酸铁;Fe2(SO4)3;yellow
四氧化三铁;Fe3O4;black
氯化亚铁;FeCl2;green
氯化铁;FeCl3;brown
硝酸亚铁;Fe(NO3)2;green
硝酸铁;Fe(NO3)3;yellow
氧化亚铁;FeO;black
氢氧化亚铁;Fe(OH)2;green
氢氧化铁;Fe(OH)3;brown
硫酸亚铁;FeSO4;green
氧化汞;HgO;red
碘;I2;purple
锰酸钾;K2MnO4;green
氧化钾;K2O;white
硫酸钾;K2SO4;white
氯化钾;KCl;white
碘化钾;KI;white
硝酸钾;KNO3;white
氢氧化钾;KOH;white
铁氰化钾;K3[Fe(CN)6];red
锂;Li;silver
镁粉;Mg;silver
氯化镁;MgCl2;white
硝酸镁;Mg(NO3)2;white
氧化镁;MgO;white
氢氧化镁;Mg(OH)2;white
硫酸镁;MgSO4;white
氯化锰;MnCl2;pink
碳酸镁;MgCO3;white
氧化钠;Na2O;white
亚硫酸钠;Na2SO3;white
硫酸钠;Na2SO4;white
偏铝酸钠;NaAlO2;white
氯化钠;NaCl;white
碳酸氢钠;NaHCO3;white
硫酸氢钠;NaHSO4;white
硝酸钠;NaNO3;white
氢氧化钠;NaOH;white
硫酸铵;(NH4)2SO4;white
氯化铵;NH4Cl;white
硝酸铵;NH4NO3;white
红磷;P（红磷）;red
白磷;P4;white
五氧化二磷;P4O10;white
铅;Pb;gray
氯化铅;PbCl2;white
二氧化铅;PbO2;black
铂粉;Pt;gray
硫粉;S8;yellow
硅;Si;gray
锌粉;Zn;gray
氯化锌;ZnCl2;white
硫酸锌;ZnSO4;white
大理石块;CaCO3（含杂质）;white
二氧化硅;SiO2;white
碱式碳酸铜;Cu2(OH)2CO3;green
活性炭;C（多孔）;black
醋酸钠;CH3COONa;white
硫化钠;Na2S;white
硫氢化钠;NaHS;white
氢氧化银;AgOH（不稳定）;brown
碳酸氢铵;NH4HCO3;white
碳酸铵;(NH4)2CO3;white
粗盐;混合物（以 NaCl 为主）;white
硫代硫酸钠;Na2S2O3;white
硫酸锰;MnSO4;pink
重铬酸钾;K2Cr2O7;orange
硫氰化钾;KSCN;white
海带灰;成分未指定的混合物;gray
八水合氢氧化钡;Ba(OH)2·8H2O;white
硼酸;H3BO3;white
碘化钠;NaI;white
溴化钠;NaBr;white
沸石;组成未指定的铝硅酸盐;white
胆矾;CuSO4·5H2O;blue
碳酸银;Ag2CO3;yellow
木炭粉;C（含杂质）;black
葡萄糖;C6H12O6;white
氧化亚铜;Cu2O;red
聚乙烯;(C2H4)n;white
锰;Mn;gray
次氯酸钙;Ca(ClO)2;white
硫化铜;CuS;black
碳酸氢钾;KHCO3;white
碳酸钾;K2CO3;white
钾;K;silver
钙;Ca;silver
铜丝段;Cu;copper
硝酸铅;Pb(NO3)2;white
短镁条;Mg;silver
铝片;Al;silver
小铜片;Cu;copper
乙炔银;Ag2C2;gray
过碳酸钠;2Na2CO3·3H2O2;white
锌粒;Zn;gray'''
items=[]
for line in lines.splitlines():
    name,formula,color=line.split(';')
    items.append(dict(id=f'solid{len(items)+1:03}',name=name,formula=formula,phase='solid',appearance=color,model='bottle',action='solid',category='固体药品',default_mass_g=10,operational=False,scope='实物目录与取用称量；此固体的反应模型尚未验证'))
assert len({x['name'] for x in items})==len(items)
# Only these finite solid phases have an existing validated path, not arbitrary mixtures.
for e in items:
    if e['name']=='碳酸钙': e.update(batch_reagent=18,operational=True,scope='25°C 方解石溶解 / 稀盐酸 / CO₂ 平衡专用实验')
    if e['name']=='胆矾': e['alias_of']='solid045'
# Include existing gypsum as an additional supported solid; no relabelling of anhydrous CaSO4.
items.append(dict(id='solid143',name='石膏',formula='CaSO4·2H2O',phase='solid',appearance='white',model='bottle',action='solid',category='固体药品',default_mass_g=10,batch_reagent=19,operational=True,scope='25°C 石膏溶解平衡专用实验'))
assert len({x['id'] for x in items})==len(items)
for p in [ROOT/'data/materials.json',ROOT/'godot/data/materials.json']: p.write_text(json.dumps(dict(schema=1,items=items),ensure_ascii=False,indent=2)+'\n')
print(len(items),'solid packages')
