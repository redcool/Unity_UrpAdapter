
1
enable srp batch:
    replace 
    Unity_UrpAdapter\CGIncludes 
    to
    Unity\Editor\Data\CGIncludes


2 update cg shader:
    1 import Lib/DrpVaribles.hlsl
    2 replace UnityCG.cginc to DrpVariables.hlsl