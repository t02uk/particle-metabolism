__DEBUG__ = false
pass = undefined

class God
  @setup: ->
    @deviceWidth = 640.0
    @deviceHeight = 480.0
    @scene = new THREE.Scene()
    @scene.fog = new THREE.FogExp2(0x000000, 0.08)
    @camera = new THREE.PerspectiveCamera(60, @deviceWidth / @deviceHeight, Math.pow(0.1, 8), Math.pow(10, 3))
    @renderer = new THREE.WebGLRenderer(antialias: true)
    @renderer.setSize(@deviceWidth, @deviceHeight)
    @renderer.setClearColor(0x7788cc, 0)
    c = document.getElementById('c')
    c.appendChild(@renderer.domElement)

    World.setup(@scene)
    @particles = new Particles(@scene)

  @start: ->
    startTime = +new Date()
    render = =>
      @tick = new Date() - startTime
      @particles.update()
      @camera.position.z = Math.sin(@tick * 0.00022) * 3
      @camera.position.y = Math.sin(@tick * 0.000093) * 3 + 2.0
      @camera.position.x = Math.cos(@tick * 0.000054) * 3
      if Math.random() < 0.001 or @cameraTarget is undefined
        @cameraTarget = @particles.particles[~~(Math.random() * @particles.particles.length)].p
      @camera.lookAt(@cameraTarget)
      requestAnimationFrame(render)
      @renderer.render(@scene, @camera)
    render()

class World
  @setup: (scene) ->
    World.size = @size = 5
    vertices = [
      new THREE.Vector3(-@size,-@size,-@size),
      new THREE.Vector3( @size,-@size,-@size),
      new THREE.Vector3( @size, @size,-@size),
      new THREE.Vector3(-@size, @size,-@size),
      new THREE.Vector3(-@size,-@size, @size),
      new THREE.Vector3( @size,-@size, @size),
      new THREE.Vector3( @size, @size, @size),
      new THREE.Vector3(-@size, @size, @size)
    ]
    
    @geometry = new THREE.Geometry()
    @geometry.vertices.push(
      vertices[0],
      vertices[1],
      vertices[2],
      vertices[3],
      vertices[7],
      vertices[4],
      vertices[5],
      vertices[6],
      vertices[2],
      vertices[6],
      vertices[7],
      vertices[3],
      vertices[0],
      vertices[4],
      vertices[5],
      vertices[1],
    )


    @material = new THREE.LineBasicMaterial
      color: 0xffffff
      opacity: 0.3
      depthTest: false
      transparent: true
      blending: THREE.AdditiveBlending

    @mesh = new THREE.Line(@geometry, @material)

    scene.add(@mesh)

class Particles
  capacity: 100

  class Particle
    constructor: (@p) ->
      s = 0.01
      @sp = new THREE.Vector3(Math.random() * s - s * 2, Math.random() * s - s * 2, Math.random() * s - s * 2)
      @numberingUID()

    numberingUID: ->
      if Particle._uid is undefined
        Particle._uid = 0
      @uid = Particle._uid++

  class Node
    constructor: (@scene, @f, @p) ->
      @material = @makeMaterial()

      @geometry = new THREE.Geometry()
      @geometry.vertices.push(
        @f.p,
        @p.p
      )

      @mesh = new THREE.Line(@geometry, @material)

      @scene.add(@mesh)

    makeMaterial: ->
      Node.material = new THREE.LineBasicMaterial
        color: 0x111111
        depthTest: false
        transparent: true
        linewidth: 1
        blending: THREE.AdditiveBlending

    update: ->
      @geometry.verticesNeedUpdate = true

    activate: ->
      @mesh.visible = true
    unactivate: ->
      @mesh.visible = false

  class NodeManager
    constructor: ->
      @nodes = []

    set: (x, y, p) ->
      if x > y
        [y, x] = [x, y]

      if @nodes[x] is undefined
        @nodes[x] = []

      @nodes[x][y] = p

    get: (x, y) ->
      if x > y
        [y, x] = [x, y]
      console.log x, y unless @nodes[x][y]

      @nodes[x][y]

    update: ->
      x = 0
      for nn in @nodes
        for n in nn
          if n
            n.update()




  constructor: (@scene) ->
    @particles = []

    @geometry = new THREE.Geometry()
    for i in [0...@capacity]
      w = World.size
      vertex = new THREE.Vector3(Math.random() * w * 2 - w, Math.random() * w * 2 - w, Math.random() * w * 2 - w)
      @geometry.vertices.push(vertex)
      particle = new Particle(vertex)
      @particles.push(particle)

    material = new THREE.PointCloudMaterial
      size: 0.2
      map: @makeTexture()
      blending: THREE.AdditiveBlending
      transparent: true
      depthTest: false
    mesh = new THREE.PointCloud(@geometry, material)
    @scene.add(mesh)

    @nm = new NodeManager()
    for x in [0...@capacity]
      for y in [x + 1...@capacity]
        @nm.set(x, y, new Node(@scene, @particles[x], @particles[y]))

  makeTexture: (tp) ->
    canvas = document.createElement('canvas')
    width = canvas.width = 256
    height = canvas.height = 256
    ctx = canvas.getContext('2d')

    grad = ctx.createRadialGradient(width / 2, height / 2, width / 8, width / 2, height / 2, width / 2)
    grad.addColorStop(0, 'rgb(96, 96, 128)')
    grad.addColorStop(0.03, 'rgb(32, 32, 64)')
    grad.addColorStop(0.30, 'rgb(32, 32, 255)')
    grad.addColorStop(1, 'rgb(0, 0, 0)')

    ctx.fillStyle = grad
    ctx.beginPath()
    ctx.rect(0, 0, width, height)
    ctx.fill()
    document.body.appendChild(canvas) if __DEBUG__
    texture = THREE.ImageUtils.loadTexture(canvas.toDataURL())
    texture

  update: ->

    for i1 in [0...@capacity]
      p1 = @particles[i1]
      for i2 in [i1 + 1...@capacity]
        p2 = @particles[i2]

        ss = 0.0001
        dist = p1.p.distanceTo(p2.p)

        if dist < 2
          if dist < 0.08
            ss *= -10000
          p1.sp.x -= (p1.p.x - p2.p.x) * ss
          p1.sp.y -= (p1.p.y - p2.p.y) * ss
          p1.sp.z -= (p1.p.z - p2.p.z) * ss

    for p in @particles
      ss = 0.995
      p.sp.x *= ss
      p.sp.y *= ss
      p.sp.z *= ss

      p.p.x += p.sp.x
      p.p.y += p.sp.y
      p.p.z += p.sp.z

      w = World.size
      if p.p.x > w
        p.p.x = -w
      if p.p.x < -w
        p.p.x = w

      if p.p.y > w
        p.p.y = -w
      if p.p.y < -w
        p.p.y = w

      if p.p.z > w
        p.p.z = -w
      if p.p.z < -w
        p.p.z = w

    for i1 in [0...@capacity]
      p1 = @particles[i1]
      for i2 in [i1 + 1...@capacity]
        p2 = @particles[i2]
        node = @nm.get(i1, i2)
        dist = p1.p.distanceTo(p2.p)

        if dist < 2
          node.activate()
        else
          node.unactivate()

    @geometry.verticesNeedUpdate = true

    @nm.update()

window.God = God
