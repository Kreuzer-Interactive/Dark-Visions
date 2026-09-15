''
'' This loads up o3a models and renders them
'' it doesn't have any sorting, this is fine for
'' a wireframe cube with backface cullung. But for
'' more complex model you'll definitly need sorting.
'' I recomend an ordering table.
''
defint a-z
'$include: '..\inc\ugl.bi'
'$include: '..\inc\dos.bi'
'$include: 'mdlview.bi'

const xRes = 320
const yRes = 240
const cFmt = UGL.8BIT

'$dynamic

''
'' A is before transformation
'' B is after  transformation
'' nBuffer = normals buffer
'' vBuffer = vertex  buffer
'' tBuffer = triangle buffer
''
dim mesh as MeshType
dim shared hVideoDC as long
dim shared hBackBDC as long
dim shared hTextrDC as long
dim cam as CameraType
dim shared tmrIni as single
dim shared tmrEnd as single
dim shared frames as single
dim shared triIndex(16000) as integer
dim shared backface as integer

dim nBufferA( MAXNORMALS-1 )   as uVector3f
dim nBufferB( MAXNORMALS-1 )   as uVector3f
dim vBufferA( MAXVERTICES-1 )  as uVector3f
dim vBufferB( MAXVERTICES-1 )  as uVector3f
dim tBufferA( MAXTRIANGLES-1 ) as Triangle                    

'$static


    doInit
    doMain
    doEnd



defint a-z
sub doInit
    shared cam as CameraType
    
    cam.ppos.z = -50

    ''
    '' Load model
    '' 
    LoadO3AModel "sphere.o3a"

    ''
    '' Init UGL    
    ''
    if ( uglInit = FALSE ) then ExitError "0x0000, Could not init UGL..."
    
    screen 13
    ''
    '' Set screen mode
    ''
    hVideoDC = uglSetVideoDC( cFmt, xRes, yRes, 1 )
    if ( hVideoDC = FALSE ) then ExitError "0x0001, Could not set video mode..."
    
    ''
    '' Create a backbuffer
    ''
    hBackBDC = uglNew( UGL.MEM, cFmt, xRes, yRes )
    if ( hBackBDC = FALSE ) then ExitError "0x0002, Could not create a backbuffer..."
    
    ''
    '' Load the texture
    ''
    hTextrDC = uglNewBMP( UGL.MEM, cFmt, "data\ugl.bmp" )
    if ( hTextrDC = FALSE ) then ExitError "0x0003, Could not load texture..."    
    
    
    
    
end sub


defint a-z
sub doMain
    shared mesh as MeshType
    shared cam as CameraType
    shared nBufferA( ) as uVector3f
    shared nBufferB( ) as uVector3f
    shared vBufferA( ) as uVector3f
    shared vBufferB( ) as uVector3f    
    
    tmrIni = timer
    do
        uglClear hBackBDC, -1
        
        ''
        '' Get key
        ''
        k$ = inkey$
        
        
        ''
        '' Objects space to World space
        ''
        mthRotX vBufferB(), vBufferA(), mesh.vtxCount, mesh.ang.x
        mthRotY vBufferB(), vBufferB(), mesh.vtxCount, mesh.ang.y
        mthRotZ vBufferB(), vBufferB(), mesh.vtxCount, mesh.ang.z
        mthTrans vBufferB(), vBufferB(), mesh.vtxCount, _
                 mesh.ppos.x, mesh.ppos.y, mesh.ppos.z
                  
        mthRotX nBufferB(), nBufferA(), mesh.triCount, mesh.ang.x
        mthRotY nBufferB(), nBufferB(), mesh.triCount, mesh.ang.y
        mthRotZ nBufferB(), nBufferB(), mesh.triCount, mesh.ang.z
        
        ''
        '' World Space to cam space ( Euler cam )
        ''
        mthTrans vBufferB(), vBufferB(), mesh.vtxCount, _
                  -cam.ppos.x, -cam.ppos.y, -cam.ppos.z
        mthRotZ vBufferB(), vBufferB(), mesh.vtxCount, -cam.ang.z
        mthRotY vBufferB(), vBufferB(), mesh.vtxCount, -cam.ang.y
        mthRotX vBufferB(), vBufferB(), mesh.vtxCount, -cam.ang.x
        
        mthRotZ nBufferB(), nBufferB(), mesh.triCount, -cam.ang.z
        mthRotY nBufferB(), nBufferB(), mesh.triCount, -cam.ang.y
        mthRotX nBufferB(), nBufferB(), mesh.triCount, -cam.ang.x
        
        
        ''
        '' Change the rotation angle
        ''
        
        if ( mesh.ang.x > 359.0 ) then mesh.ang.x = 0.0
        if ( mesh.ang.y > 359.0 ) then mesh.ang.y = 0.0
        
        if ( k$ = "w" ) then mesh.ppos.z = mesh.ppos.z + 1.0
        if ( k$ = "s" ) then mesh.ppos.z = mesh.ppos.z - 1.0
        
        if ( k$ = "b" ) then backface = not backface
        
        
        'if ( k$ = "e" ) then 
            mesh.ang.x = mesh.ang.x + 0.4
            mesh.ang.y = mesh.ang.y + 0.6
        'end if
        
        
        ''
        '' Render and flip page
        ''        
        doRender 
        uglPut hVideoDC, 0, 0, hBackBDC
        frames = frames + 1.0        
        
    loop until ( k$ = chr$( 27 ) )    
    tmrEnd = timer
    
end sub


defint a-z
sub doEnd

    ''
    '' Deinit UGL
    ''
    uglRestore
    uglEnd

    ''
    '' Reset screen
    '' 
    screen 0
    width 80, 25
    print "FPS: " + str$(cint(frames /(tmrEnd-tmrIni)))
    
end sub


defint a-z
sub doRender    
    static camu as uvector3f
    shared mesh as MeshType
    shared cam as CameraType
    static vtx as tritype
    shared nBufferB( ) as uVector3f    
    shared vBufferB( ) as uVector3f
    shared tBufferA( ) as Triangle
    
    
    ''
    '' Normalize the cam pos vector
    ''
    mag! = cam.ppos.x*cam.ppos.x + _
           cam.ppos.y*cam.ppos.y + _
           cam.ppos.z*cam.ppos.z
           
    if ( mag! ) then
        camu.x = cam.ppos.x / mag!
        camu.y = cam.ppos.y / mag!
        camu.z = cam.ppos.z / mag!
    else
        camu.x = cam.ppos.x
        camu.y = cam.ppos.y
        camu.z = cam.ppos.z
    end if

  
    memFillEx triIndex(0), 16001*2, -1
    
    for  i = 0 to mesh.triCount-1            
            tBufferA(i).tnext = -1
            tBufferA(i).avgz  = (vBufferB(tBufferA(i).p1).z + _
                                 vBufferB(tBufferA(i).p2).z + _
                                 vBufferB(tBufferA(i).p3).z ) * (1.0/3.0)

            indx = int( tBufferA(i).avgz )
            
            if ( triIndex(indx) = -1 ) then
                triIndex(indx) = i
            else
                tprev = -1
                tcurr = triIndex(indx)
                
                do                   
                    if ( (tBufferA(i).avgz >= tBufferA(tcurr).avgz) ) then
                        tBufferA(i).tnext = tcurr
                        
                        if ( tprev <> -1 ) then
                            tBufferA(tprev).tnext = i                            
                        end if
                        
                        if ( indx = tcurr ) then
                            triIndex(indx) = i
                        end if
                        
                        exit do
                    end if
                    
                    if ( tBufferA(tcurr).tnext = -1 ) then
                        tBufferA(tcurr).tnext = i                        
                        exit do
                    end if
                    
                    tprev = tcurr
                    tcurr = tBufferA(tcurr).tnext
                loop                    
                
            end if
    next i
    

    ''
    '' main rendering loop
    '' 
    for  i = 16000 to 0 step -1
    
        ti = triIndex(i)
        if ( ti <> -1 ) then
            do
                ''
                '' Back face cull
                ''
                indx = tBufferA(ti).nIndx
                dp! = nBufferB(indx).x*camu.x + _
                      nBufferB(indx).y*camu.y + _
                      nBufferB(indx).z*camu.z
                
                ''
                '' Check if visible
                ''              
                if ( backface ) then
                    
                    if ( dp! > 0.0 ) then
                    
                        p1 = tBufferA(ti).p1
                        p2 = tBufferA(ti).p2
                        p3 = tBufferA(ti).p3            
                        
                        ''
                        '' z can't be zero or there will be
                        '' division by zero
                        ''
                        
                        vtx.v1.x = (160.0 + vBufferB(p1).x*256 / vBufferB(p1).z) * (xRes/320.0)
                        vtx.v1.y = (100.0 + vBufferB(p1).y*256 / vBufferB(p1).z) * (yRes/200.0)
                        vtx.v1.z = 1.0
                        
                        vtx.v2.x = (160.0 + vBufferB(p2).x*256 / vBufferB(p2).z) * (xRes/320.0)
                        vtx.v2.y = (100.0 + vBufferB(p2).y*256 / vBufferB(p2).z) * (yRes/200.0)
                        vtx.v2.z = 1.0
                        
                        vtx.v3.x = (160.0 + vBufferB(p3).x*256 / vBufferB(p3).z) * (xRes/320.0)
                        vtx.v3.y = (100.0 + vBufferB(p3).y*256 / vBufferB(p3).z) * (yRes/200.0)
                        vtx.v3.z = 1.0
                        
                        vtx.v1.u = tBufferA(ti).u1
                        vtx.v1.v = tBufferA(ti).v1
                        vtx.v2.u = tBufferA(ti).u2
                        vtx.v2.v = tBufferA(ti).v2
                        vtx.v3.u = tBufferA(ti).u3
                        vtx.v3.v = tBufferA(ti).v3
                        
                                    
                        uglTriT hBackBDC, vtx, ugl.mask.true, hTextrDC
                    end if                
                    
                else
                    ''
                    '' Draw with some other color ?
                    ''
                    
                        p1 = tBufferA(ti).p1
                        p2 = tBufferA(ti).p2
                        p3 = tBufferA(ti).p3            
                        
                        ''
                        '' z can't be zero or there will be
                        '' division by zero
                        ''
                        
                        vtx.v1.x = (160.0 + vBufferB(p1).x*256 / vBufferB(p1).z) * (xRes/320.0)
                        vtx.v1.y = (100.0 + vBufferB(p1).y*256 / vBufferB(p1).z) * (yRes/200.0)
                        vtx.v1.z = 1.0 / vBufferB(p1).z
                        
                        vtx.v2.x = (160.0 + vBufferB(p2).x*256 / vBufferB(p2).z) * (xRes/320.0)
                        vtx.v2.y = (100.0 + vBufferB(p2).y*256 / vBufferB(p2).z) * (yRes/200.0)
                        vtx.v2.z = 1.0 / vBufferB(p2).z
                        
                        vtx.v3.x = (160.0 + vBufferB(p3).x*256 / vBufferB(p3).z) * (xRes/320.0)
                        vtx.v3.y = (100.0 + vBufferB(p3).y*256 / vBufferB(p3).z) * (yRes/200.0)
                        vtx.v3.z = 1.0 / vBufferB(p3).z
                        
                        vtx.v1.u = tBufferA(ti).u1 '* vtx.v1.z
                        vtx.v1.v = tBufferA(ti).v1 '* vtx.v1.z
                        vtx.v2.u = tBufferA(ti).u2 '* vtx.v2.z
                        vtx.v2.v = tBufferA(ti).v2 '* vtx.v2.z
                        vtx.v3.u = tBufferA(ti).u3 '* vtx.v3.z
                        vtx.v3.v = tBufferA(ti).v3 '* vtx.v3.z
                                    
                        uglTriT hBackBDC, vtx, ugl.mask.true, hTextrDC
                end if
                
                ti = tBufferA(ti).tnext
            loop until ( ti = -1 )
        end if
        
    next i    
end sub


defint a-z
sub mthRotX ( vout() as uVector3f, vin() as uVector3f, _
              vtxCount as integer, angle as single )

    static i as integer    
    static ang as single
    static vtmp as uVector3f
    static cosp as single, sinp as single
    
    ''
    '' Convert degrees to radians
    ''
    ang = angle * DEG2RAG
    
    ''
    '' Get the cosine and sine for 
    '' the angle
    ''
    sinp = sin( ang )
    cosp = cos( ang )

    '' 
    '' Rotate the vertices about the
    '' x axis
    ''              
    for  i = 0 to vtxCount-1
        vtmp.y = vin(i).y*cosp - vin(i).z*sinp
        vtmp.z = vin(i).z*cosp + vin(i).y*sinp
        
        vout(i).x = vin(i).x
        vout(i).y = vtmp.y
        vout(i).z = vtmp.z
    next i
    
end sub


defint a-z
sub mthRotY ( vout() as uVector3f, vin() as uVector3f, _
              vtxCount as integer, angle as single )

    static i as integer    
    static ang as single
    static vtmp as uVector3f
    static cosp as single, sinp as single
    
    ''
    '' Convert degrees to radians
    ''
    ang = angle * DEG2RAG
    
    ''
    '' Get the cosine and sine for 
    '' the angle
    ''
    sinp = sin( ang )
    cosp = cos( ang )

    '' 
    '' Rotate the vertices about the
    '' y axis
    ''              
    for  i = 0 to vtxCount-1        
        vtmp.z = vin(i).z*cosp - vin(i).x*sinp
        vtmp.x = vin(i).x*cosp + vin(i).z*sinp
        
        vout(i).x = vtmp.x
        vout(i).y = vin(i).y
        vout(i).z = vtmp.z
    next i
    
end sub


defint a-z
sub mthRotZ ( vout() as uVector3f, vin() as uVector3f, _
              vtxCount as integer, angle as single )

    static i as integer    
    static ang as single
    static vtmp as uVector3f
    static cosp as single, sinp as single
    
    ''
    '' Convert degrees to radians
    ''
    ang = angle * DEG2RAG
    
    ''
    '' Get the cosine and sine for 
    '' the angle
    ''
    sinp = sin( ang )
    cosp = cos( ang )    

    '' 
    '' Rotate the vertices about the
    '' z axis
    ''              
    for  i = 0 to vtxCount-1
        vtmp.x = vin(i).x*cosp + vin(i).y*sinp
        vtmp.y = vin(i).y*cosp - vin(i).x*sinp
        
        vout(i).x = vtmp.x
        vout(i).y = vtmp.y
        vout(i).z = vin(i).z
    next i    
    
end sub


defint a-z
sub mthTrans ( vout() as uVector3f, vin() as uVector3f, _
              vtxCount as integer, tx as single, ty as single, _
              tz as single )

    static i as integer    
    static vtmp as uVector3f  


    '' 
    '' Translate the vertices    
    ''              
    for  i = 0 to vtxCount-1
        vtmp.x = vin(i).x + tx
        vtmp.y = vin(i).y + ty
        vtmp.z = vin(i).z + tz
        
        vout(i).x = vtmp.x
        vout(i).y = vtmp.y
        vout(i).z = vtmp.z
    next i    
    
end sub


defint a-z
sub mthScale ( vout() as uVector3f, vin() as uVector3f, _
              vtxCount as integer, sx as single, sy as single, _
              sz as single )

    static i as integer    
    static vtmp as uVector3f  


    '' 
    '' Scale the vertices    
    ''              
    for  i = 0 to vtxCount-1
        vtmp.x = vin(i).x * sx
        vtmp.y = vin(i).y * sy
        vtmp.z = vin(i).z * sz
        
        vout(i).x = vtmp.x
        vout(i).y = vtmp.y
        vout(i).z = vtmp.z
    next i    
    
end sub



defint a-z
sub LoadO3AModel ( filename as string )    
    dim x as single
    dim y as single
    dim z as single    
    dim mstr as string
    shared mesh as MeshType
    
    shared nBufferA( ) as uVector3f    
    shared vBufferA( ) as uVector3f    
    shared tBufferA( ) as Triangle
    
    
    open filename for input as #1
    
    if ( lof( 1 ) = 0 ) then
        print "File doesn't exist..."
        end
    end if
    
    ''
    '' Skip file ID
    '' 
    line input #1, mstr
    
    ''
    '' Number of tris and vertices
    ''
    input #1, mesh.vtxCount, mesh.triCount    
    
   
    if ( mesh.vtxCount > MAXVERTICES ) then
        print "To many vertices..."
        end        
    end if        
    
    if ( mesh.triCount > MAXTRIANGLES ) then
        print "To many triangles..."
        end        
    end if
    
    
    
    ''
    '' Load vertices
    ''
    for  i = 0 to mesh.vtxCount-1
        input #1, vBufferA(i).x, _
                  vBufferA(i).y, _
                  vBufferA(i).z
    next i
    
    ''
    '' Skip vertex normals
    ''
    for  i = 0 to mesh.vtxCount-1
        input #1, x, y, z
    next i    
    
    ''
    '' Load the triangle data
    ''
    for  i = 0 to mesh.triCount-1
        input #1, tBufferA(i).p1, _
                  tBufferA(i).p2, _
                  tBufferA(i).p3                  
                  tBufferA(i).nIndx = i
        triIndex(i) = i                  
    next i    
    
    
    ''
    '' Load the tri normals
    ''
    for  i = 0 to mesh.triCount-1
        input #1, nBufferA(i).x, _
                  nBufferA(i).y, _
                  nBufferA(i).z
    next i    
    

    
    ''
    '' Skip vertex normals
    ''
    for  i = 0 to mesh.triCount-1
        input #1, tBufferA(i).u1, tBufferA(i).v1, _
                  tBufferA(i).u2, tBufferA(i).v2, _
                  tBufferA(i).u3, tBufferA(i).v3                  
    next i    
    
    ''
    '' Recalculate the normals ?
    '' n = [v1 - v2] × [v2 - v3]
    '' not the vertex order expected ?
    ''
    
    for  i = 0 to mesh.triCount-1
        v1 = tBufferA(i).p1
        v2 = tBufferA(i).p2
        v3 = tBufferA(i).p3        
        
        ''
        '' u = v1 - v2
        '' v = v2 - v3
        ''        
        ux! = vBufferA(v1).x - vBufferA(v2).x
        uy! = vBufferA(v1).y - vBufferA(v2).y
        uz! = vBufferA(v1).z - vBufferA(v2).z
        
        vx! = vBufferA(v2).x - vBufferA(v3).x
        vy! = vBufferA(v2).y - vBufferA(v3).y
        vz! = vBufferA(v2).z - vBufferA(v3).z
        
        ''
        '' Since the vertex order is counter clockwise
        '' we have to do v cross u instead of u cross v
        '' 
        nBufferA(i).x = uy!*vz! - uz!*vy!
        nBufferA(i).y = uz!*vx! - ux!*vz!
        nBufferA(i).z = ux!*vy! - uy!*vx!        
    next i
    
    close #1
end sub


defint a-z
sub ExitError ( msg as string )
    uglRestore
    uglEnd
    
    screen 0
    width 80, 25
    print "Error: " + msg
    end
end sub






