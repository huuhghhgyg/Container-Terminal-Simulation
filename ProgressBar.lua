function ProgressBar(intiPercent, px, py, pz)
    local pgb = {
        px = px or 50,
        py = py or 2,
        pz = pz or 0,
        value = intiPercent or 0,
    }
    
    scene.setenv({
        camtype = 'ortho'
    })

    pgb.border = scene.addobj('polyline', {
        vertices = {-pgb.px, -pgb.py, pgb.pz, -pgb.px, pgb.py, pgb.pz, pgb.px, pgb.py, pgb.pz, pgb.px, -pgb.py, pgb.pz, -pgb.px,
                    -pgb.py, pgb.pz-pgb.px, -pgb.py, pgb.pz}
    })
    pgb.bar = scene.addobj('polygon', {
        vertices = {-pgb.px, -pgb.py, pgb.pz, -pgb.px, pgb.py, pgb.pz, pgb.px, pgb.py, pgb.pz, pgb.px, -pgb.py, pgb.pz},
        color = 'gray'
    })

    function pgb:setp(percent)
        pgb.value = percent
        local x = pgb.px*percent-pgb.px
        pgb.bar:setscale(percent,1,1)
        pgb.bar:setpos(x, 0, pgb.pz)
        scene.render()
    end
    
    function pgb:del()
        pgb.border:delete()
        pgb.bar:delete()
    end

    pgb:setp(pgb.value)

    return pgb
end

-- 使用示例
-- local pgb = ProgressBar(0.1)
-- debug.pause()
-- pgb:setp(0.2)
-- debug.pause()
-- pgb:setp(1)
-- debug.pause()
-- pgb:del()
scene.render()