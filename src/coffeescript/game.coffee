# blot vs. blot

PLAYER_A = 1
PLAYER_B = 2
EMPTY = 0


shuffle = (a) ->
    # http://coffeescriptcookbook.com/chapters/arrays/shuffling-array-elements
    for i in [a.length-1..1]
        j = Math.floor Math.random() * (i + 1)
        [a[i], a[j]] = [a[j], a[i]]
    return a


class KaluzaGame
    size: 0
    map: []
    state: []

    fgColors: {
        0: 'rgb(240, 240, 240)'
        1: 'rgb(137, 188, 255)'
        2: 'rgb(235, 93, 70)'
    }
    bgColors: {
        0: 'rgb(210, 210, 210)'
        1: 'rgb(204, 226, 255)'
        2: 'rgb(235, 154, 141)'
    }
    hoverColors: {
        1: 'rgb(166, 204, 255)'
        2: 'rgb(235, 124, 106)'
    }

    hover: {
        1: null
        2: null
    }

    active_player: PLAYER_A

    constructor: (@size=9) ->
        @createMap @size
        @createCanvas()
        @refresh()

    createMap: ->
        for x in [0..@size-1]
            @state.push (0 for y in [0..@size-1])
            value  = (a, b, size) -> if (a+b < size) then ((a+b)*100+100) else ((2*(size-1)-a-b)*100+100)
            @map.push (value(x, y, @size) for y in [0..@size-1])

        @state[0][0] = PLAYER_A
        @state[@size-1][@size-1] = PLAYER_B

    refresh: ->
        @resizeCanvas()
        @createDrawingContext()
        @draw()

    createCanvas: ->
        @canvas = document.createElement 'canvas'
        document.getElementById('wrap').appendChild @canvas

    resizeCanvas: ->
        @cavnasSize = Math.min(window.innerHeight, window.innerWidth) - 20
        @canvas.height = @cavnasSize
        @canvas.width = @cavnasSize

    createDrawingContext: ->
        @drawingContext = @canvas.getContext '2d'

    getCenter: (x, y) ->
        unit = Math.round(@cavnasSize / (@size*2 + 2))
        centerX = 2*unit + x*2*unit
        centerY = 2*unit + y*2*unit
        return [centerX, centerY]

    drawCircle: (centerX, centerY, radius, color) ->
        @drawingContext.beginPath()
        @drawingContext.arc centerX, centerY, radius, 0, 2 * Math.PI, false
        @drawingContext.closePath()
        @drawingContext.fillStyle = color
        @drawingContext.fill()

    drawText: (centerX, centerY, size, color, text) ->
        @drawingContext.font = size+'pt Tahoma'
        @drawingContext.textAlign = 'center'
        @drawingContext.textBaseline = 'top'
        @drawingContext.fillStyle = color
        @drawingContext.fillText text, centerX, centerY-size

    getHoverPlayer: (x, y) ->
        for player in [PLAYER_A, PLAYER_B]
            if @hover[player]?
                [hoverX, hoverY] = @hover[player]
                if x == hoverX and y == hoverY
                    return player
        return null

    drawField: (x, y) ->
        player = @state[x][y]
        unit = Math.round(@cavnasSize / (@size*2 + 2))
        [centerX, centerY] = @getCenter x, y

        fgColor = @fgColors[player]
        bgColor = if player != EMPTY then @bgColors[player] else null
        hover = @getHoverPlayer x, y
        obtainable = @isObtainable x, y, PLAYER_A

        if (hover == PLAYER_A and obtainable) or hover == PLAYER_B
            bgColor = @hoverColors[hover]

        if player == EMPTY and obtainable
            fgColor = @bgColors[player]

        if bgColor?
            @drawCircle centerX, centerY, unit * 1.2, bgColor
        @drawCircle centerX, centerY, unit * 0.8, fgColor

        @drawText centerX, centerY, Math.round(unit/2), 'white', @map[x][y]

    draw: ->
        @drawingContext.clearRect 0, 1, @cavnasSize, @cavnasSize

        stats = @getStats()
        center = Math.round(@cavnasSize/2)
        fontSize = Math.round(@cavnasSize/4)
        if stats[PLAYER_B] == 0
            console.log 'player A wins'
            @drawText center, center, fontSize, 'red', 'WIN'
            @active_player = EMPTY
        else if stats[PLAYER_A] == 0
            console.log 'player B wins'
            @drawText center, center, fontSize, 'red', 'LOSS'
            @active_player = EMPTY
        else
            for x in [0..@size-1]
                for y in [0..@size-1]
                    @drawField x, y

    getStats: () ->
        stats = {
            1: 0
            2: 0
        }
        for x in [0..@size-1]
            for y in [0..@size-1]
                for player in [PLAYER_A, PLAYER_B]
                    if @state[x][y] == player
                        stats[player] += @map[x][y]
        return stats

    getMouseLocation: (e) ->
        x = y = null
        if e.pageX != undefined and e.pageY != undefined
            x = e.pageX
            y = e.pageY
        else
            x = e.clientX + document.body.scrollLeft + document.documentElement.scrollLeft
            y = e.clientY + document.body.scrollTop + document.documentElement.scrollTop

        x -= @canvas.offsetLeft
        y -= @canvas.offsetTop
        x = Math.min x, @cavnasSize
        y = Math.min y, @cavnasSize
        return [x,y]

    getDistance: (x1, y1, x2, y2) ->
        xd = x2-x1
        yd = y2-y1
        return Math.sqrt(xd*xd + yd*yd)

    getNearestField: (mouseX, mouseY) ->
        minDistance = Infinity
        nearest = null
        for x in [0..@size-1]
            for y in [0..@size-1]
                [centerX, centerY] = @getCenter x, y
                distance = @getDistance(mouseX, mouseY, centerX, centerY)
                if distance < minDistance
                    minDistance = distance
                    nearest = [x, y]
        return nearest

    onClick: (e) ->
        if @active_player == PLAYER_A
            [mouseX, mouseY] = @getMouseLocation(e)
            clicked = @getNearestField(mouseX, mouseY)

            if clicked?
                [x, y] = clicked
                if @clickField x, y, PLAYER_A, PLAYER_B
                    @hover[PLAYER_A] = null
                    @draw()

                    @opponentTurn()

        return false

    onMouseMove: (e) ->
        if @active_player == PLAYER_A
            [mouseX, mouseY] = @getMouseLocation(e)
            nearest = @getNearestField(mouseX, mouseY)
            if nearest? and (@getFieldId nearest) != (@getFieldId @hover[PLAYER_A])
                @hover[PLAYER_A] = nearest
                @draw()

        return false

    onMouseOut: (e) ->
        if @active_player == PLAYER_A
            @hover[PLAYER_A] = null
            @draw()
        return false


    clickField: (x, y, player, opponent) ->
        if @state[x][y] == player
            console.log "player #{player} releases [#{x}, #{y}] field"
            return @releaseField x, y, player
        else if @isObtainable x, y, player
            if @state[x][y] == opponent
                console.log "player #{player} will fight for [#{x}, #{y}] field"
                return @fightForField x, y, player, opponent
            else
                console.log "player #{player} obtains [#{x}, #{y}] field"
                return @obtainField x, y, player

        return false

    releaseField: (fieldX, fieldY, player) ->
        group = @getGroup(fieldX, fieldY)
        if group.length == 1
            console.log "can't release last field in group!"
            return false

        points = 0
        for [x, y] in group
            points += @map[x][y]

        value = Math.round(points / (group.length-1))
        for [x, y] in group
            @map[x][y] = value

        @state[fieldX][fieldY] = EMPTY
        @map[fieldX][fieldY] = 0
        return true

    fightForField: (defenseX, defenseY, player, opponent) ->
        [x, y] = [defenseX, defenseY]
        attackValue = 0
        attackField = null
        for [nearX, nearY] in [[x-1, y], [x+1, y], [x, y-1], [x, y+1]]
            if nearX >=0 and nearX < @size and nearY >=0 and nearY < @size
                if @state[nearX][nearY] == player and @map[nearX][nearY] > attackValue
                    attackValue = @map[nearX][nearY]
                    attackField = [nearX, nearY]

        [attackX, attackY] = attackField

        maxGroup = @getGroup(attackX, attackY)
        defenseValue = @map[defenseX][defenseY]

        if attackValue > defenseValue
            console.log "player #{player} won [#{x}, #{y}] field"
            # win - player is decreased and obtain opponent field
            @map[attackX][attackY] = attackValue - defenseValue
            @map[defenseX][defenseY] = 0

            @obtainField defenseX, defenseY, player

        else if attackValue == defenseValue
            console.log "it's a draw"
            # draw - clear both fields
            @map[defenseX][defenseY] = 0
            @state[defenseX][defenseY] = EMPTY

            @map[attackX][attackY] = 0
            @state[attackX][attackY] = EMPTY

        else
            # fail - opponent is decreased
            console.log "player #{player} loosed [#{x}, #{y}] field"
            @map[attackX][attackY] = 0
            @state[attackX][attackY] = EMPTY
            @map[defenseX][defenseY] = defenseValue - attackValue
            @normalizeGroup defenseX, defenseY

        return true

    obtainField: (fieldX, fieldY, player) ->
        @state[fieldX][fieldY] = player
        @normalizeGroup fieldX, fieldY

    normalizeGroup: (fieldX, fieldY) ->
        group = @getGroup(fieldX, fieldY)
        points = 0
        for [x, y] in group
            points += @map[x][y]

        value = Math.round(points / group.length)
        for [x, y] in group
            @map[x][y] = value

    isObtainable: (x, y, player) ->
        if @state[x][y] == player
            return true
        for [nearX, nearY] in [[x-1, y], [x+1, y], [x, y-1], [x, y+1]]
            if nearX >=0 and nearX < @size and nearY >=0 and nearY < @size
                if @state[nearX][nearY] == player
                    return true
        return false

    getFieldId: (field) ->
        try
            [x, y] = field
            return "#{x}-#{y}"
        catch error
            return null

    getGroup: (startX, startY) ->
        result = []
        visited = []
        toVisit = [[startX, startY]]
        player = @state[startX][startY]

        while toVisit.length > 0
            [x, y] = toVisit.pop()
            result.push [x, y]
            visited.push @getFieldId [x, y]
            for [nearX, nearY] in [[x-1, y], [x+1, y], [x, y-1], [x, y+1]]
                fieldId = @getFieldId [nearX, nearY]
                if nearX >=0 and nearX < @size and nearY >=0 and nearY < @size
                    if @state[nearX][nearY] == player and fieldId not in visited
                        toVisit.push [nearX, nearY]
        return result

    chooseField: () ->
        # split fields for three kinds
        reachable_empty = []
        reachable_opponent = []
        obtained = []
        for x in [0..@size-1]
            for y in [0..@size-1]
                if @isObtainable x, y, PLAYER_B
                    item = {field: [x, y], value: @map[x][y]}
                    if @state[x][y] == EMPTY
                        reachable_empty.push item
                    else if @state[x][y] == PLAYER_A
                        reachable_opponent.push item
                    else
                        obtained.push item

        # sort kinds
        sort_by_value = (a, b) -> a.value-b.value
        obtained.sort(sort_by_value)
        obtained.reverse()
        reachable_empty.sort(sort_by_value)
        reachable_empty.reverse()
        reachable_opponent.sort(sort_by_value)

        # expand if it's possible and if new field have more points than current field
        if reachable_empty.length > 0 and reachable_empty[0].value >= obtained[0].value
            return reachable_empty[0].field

        # attack if current field is stronger than weakest opponent field
        if reachable_opponent.length > 0 and reachable_opponent[0].value < obtained[0].value
            return reachable_opponent[0].field

        # split groups if it's possible (at least one group is bigger than one field)
        # so maybe it will be possible to attack in next turn
        if obtained.length > 1
            for item in shuffle(obtained)
                [fieldX, fieldY] = item.field
                group = @getGroup(fieldX, fieldY)
                if group.length > 0
                    return item.field

        # if none from above than we have to run away (if there is place to go)
        if reachable_empty.length > 0
            return reachable_empty[0].field

        # if surrounded than fight for weakest opponent field
        if reachable_opponent.length > 0
            reachable_opponent.reverse()
            return reachable_opponent[0].field

        # strange! - one of above should ok
        console.log 'AI failed to choose field'
        return null

    finishTurn: () =>
        [x, y] = @hover[PLAYER_B]
        @clickField x, y, PLAYER_B, PLAYER_A
        @hover[PLAYER_B] = null
        @draw()
        @active_player = PLAYER_A

    opponentTurn: () ->
        @active_player = PLAYER_B
        field = @chooseField()
        if field?
            @hover[PLAYER_B] = field
            @draw()
            setTimeout @finishTurn, 1000
            return true

        @active_player = PLAYER_A
        return false


window.game = game = new KaluzaGame(4)
window.onresize = (event) -> game.refresh(event)
game.canvas.onclick = (event) -> game.onClick(event)
game.canvas.onmousemove = (event) -> game.onMouseMove(event)
game.canvas.onmouseout = (event) -> game.onMouseOut(event)