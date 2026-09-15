const DEG2RAG           = 3.14159 / 180.0
const MAXVERTICES       = 512%
const MAXNORMALS        = MAXVERTICES
const MAXTRIANGLES      = MAXVERTICES*2


type uVector3f
    x           as single
    y           as single
    z           as single
end type

type Triangle
    p1          as integer
    p2          as integer
    p3          as integer
    nIndx       as integer
    u1          as single
    v1          as single
    u2          as single
    v2          as single
    u3          as single
    v3          as single 
    avgz        as single    
    tnext       as integer       
end type

type MeshType
    triCount    as integer
    vtxCount    as integer
    ppos        as Vector3f
    ang         as Vector3f
end type

type CameraType
    ppos        as Vector3f
    ang         as Vector3f
end type    


declare sub doInit ()
declare sub doMain ()
declare sub doEnd  ()
declare sub doRender ()
declare sub mthRotX  ( vout() as uVector3f, vin() as uVector3f, _
                       vtxCount as integer, angle as single )
declare sub mthRotY  ( vout() as uVector3f, vin() as uVector3f, _
                       vtxCount as integer, angle as single )
declare sub mthRotZ  ( vout() as uVector3f, vin() as uVector3f, _
                       vtxCount as integer, angle as single )                       
declare sub mthTrans ( vout() as uVector3f, vin() as uVector3f, _
                       vtxCount as integer, tx as single, ty as single, _
                       tz as single )                       
declare sub mthTrans ( vout() as uVector3f, vin() as uVector3f, _
                       vtxCount as integer, sx as single, sy as single, _
                       sz as single )                       
declare sub LoadO3AModel ( filename as string )    
declare sub ExitError ( msg as string )