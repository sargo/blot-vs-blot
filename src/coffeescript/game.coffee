# blot vs. blot

EMPTY = 0
PLAYER_A = 1
PLAYER_B = 2
PLAYER_C = 3
PLAYER_D = 4


pointInPoly = (point, poly) ->
    # http://stackoverflow.com/a/19100419/2342911
    inside = false
    x = point.x
    y = point.y

    vertex = poly[ poly.length - 1 ]
    x1 = vertex.x
    y1 = vertex.y

    for vertex in poly
        x2 = vertex.x
        y2 = vertex.y
        if ( y1 < y ) != ( y2 < y )
            if x1 + ( y - y1 ) / ( y2 - y1 ) * ( x2 - x1 ) < x
                inside = not inside
        x1 = x2
        y1 = y2

    return inside


shuffle = (a) ->
    # http://coffeescriptcookbook.com/chapters/arrays/shuffling-array-elements
    for i in [a.length-1..1]
        j = Math.floor Math.random() * (i + 1)
        [a[i], a[j]] = [a[j], a[i]]
    return a


class FieldWidget
    # A cirlcle with label. Cirlce color depends on field onwer, label shows
    # field value (points). Widget is resized and moved be Renderer.

    group: null
    circle: null
    label: null

    #        empty       player A,  player B,  Player C,  Player D
    #        gray        blue       red        green      yellow
    colors: ['#7f8c8d', '#3498db', '#c0392b', '#2ecc71', '#d35400']

    constructor: (field) ->
        @group = new Kinetic.Group

        @circle = new Kinetic.Circle
            x: 0
            y: 0
            radius: 30
            fill: @colors[field.owner]

        @label = new Kinetic.Text
            x: 0
            y: 0
            text: field.value
            align: 'center'
            fontSize: 32
            fontFamily: 'Calibri'
            fontStyle: 'bold'
            fill: '#2c3e50'


        @centerLabel()

        @group.add @circle
        @group.add @label

    centerLabel: () ->
        # place label in center of widget
        @label.offsetX(@label.width()/2);
        @label.offsetY(@label.height()/2);

    update: (field) ->
        # update widget params after field change
        @circle.fill @colors[field.owner]
        @label.setText field.value
        @centerLabel()

    move: (x, y) ->
        # to move widget to absolute position we have to calculate relative position
        # from current position
        relativeX = x - @group.x()
        relativeY = y - @group.y()
        @group.move {x: relativeX, y: relativeY}

    scale: (scale) ->
        # always scale with ration=1 (the same in both dimensions)
        @group.scale {x: scale, y: scale}


class Field
    # State of field on a board.

    x: null
    y: null
    id: null
    value: null
    owner: null
    widget: null

    constructor: (@x, @y, @value, @owner=EMPTY) ->
        @id = "#{@x}-#{@y}"
        @widget = new FieldWidget @

    setOwner: (@owner) ->
        @widget.update(@)

    setValue: (@value) ->
        @widget.update(@)


class Board
    # Grid of fields.

    size: 0
    fields: []

    constructor: (@size=9, playersNo=2) ->
        @createBoard @size
        @placePlayers playersNo

    createBoard: ->
        # create size x size board, calculate initial value of fields
        for x in [0..@size-1]
            @fields.push (
                new Field x, y, @getInitialFieldValue x, y, @size for y in [0..@size-1]
            )

    placePlayers: (playersNo)->
        # set initial position of players
        @fields[0][0].setOwner(PLAYER_A)
        @fields[@size-1][@size-1].setOwner(PLAYER_B)
        if playersNo > 2
            @fields[@size-1][0].setOwner(PLAYER_C)
        if playersNo > 3
            @fields[0][@size-1].setOwner(PLAYER_D)

    getInitialFieldValue: (a, b, size) ->
        if (a+b < size) then ((a+b)*2+1) else ((2*(size-1)-a-b)*2+1)

    getNearFields: (field) ->
        # get neighbours of a fields, check bounds of board
        #
        #             | neighbour1 |
        # --------------------------------------
        #  neighbour3 |   field    | neighbour4
        # --------------------------------------
        #             | neighbour2 |
        #
        result = []
        for [nearX, nearY] in [[field.x-1, field.y], [field.x+1, field.y], [field.x, field.y-1], [field.x, field.y+1]]
            if nearX >=0 and nearX < @size and nearY >=0 and nearY < @size
                result.push @fields[nearX][nearY]
        return result

    getBlot: (startField) ->
        # get all fields that are in one blot (fields in neighborhood have the same owner)
        #
        #  blot1 | blot1 | blot1
        # -----------------------
        #  blot1 |       |
        # -----------------------
        #        | blot2 | blot2

        blot = []
        visited = []
        toVisit = [startField]

        # similar to BFS algorithm
        while toVisit.length > 0
            field = toVisit.pop()
            if field.id not in visited
                blot.push field
                visited.push field.id
                for nearField in @getNearFields field
                    if nearField.owner == startField.owner and nearField.id not in visited
                        toVisit.push nearField
        return blot

    getBlots: () ->
        # get all blots found on a board
        blots = []
        visited = []
        for x in [0..@size-1]
            for y in [0..@size-1]
                field = @fields[x][y]
                if field.id not in visited
                    blot = @getBlot field
                    blots.push blot
                    for blotMember in blot
                        visited.push blotMember.id
        return blots


class BlotWidget
    # A blob that contains all fields inside blot.

    blot: null
    board: null
    group: null
    shape: null

    #        empty       player A,  player B,  Player C,  Player D
    colors: ['#95a5a6', '#2980b9', '#e74c3c', '#27ae60', '#e67e22']

    move: (x, y) ->
        # to move widget to absolute position we have to calculate relative position
        # from current position
        relativeX = x - @group.x()
        relativeY = y - @group.y()
        @group.move {x: relativeX, y: relativeY}

    scale: (scale) ->
        # always scale with ration=1 (the same in both dimensions)
        @group.scale {x: scale, y: scale}

    getEdge: (field, mode, padding) ->
        # get coordinates of field edge
        #
        #   /----------\
        #  /            \
        #  |            |
        #  |            |
        #  \            /
        #   \----------/
        #
        edgeSize = 100
        padding = if padding then 10 else -10
        cornerRadius = 35

        offsetX = field.x * edgeSize
        offsetY = field.y * edgeSize
        if mode == 'top'
            return [
                {x: offsetX + padding + cornerRadius, y: offsetY + padding},
                {x: offsetX + edgeSize - padding - cornerRadius, y: offsetY + padding},
            ]
        else if mode == 'right'
            return [
                {x: offsetX + edgeSize - padding, y: offsetY + padding + cornerRadius},
                {x: offsetX + edgeSize - padding, y: offsetY + edgeSize - padding - cornerRadius},
            ]

        else if mode == 'bottom'
            return [
                {x: offsetX + edgeSize - padding - cornerRadius, y: offsetY + edgeSize - padding},
                {x: offsetX + padding + cornerRadius, y: offsetY + edgeSize - padding},
            ]
        else if mode == 'left'
            return [
                {x: offsetX + padding, y: offsetY + edgeSize - padding - cornerRadius},
                {x: offsetX + padding, y: offsetY + padding + cornerRadius},
            ]
        else
            throw new Error "Incorrect mode #{mode}!"

    getPossibleNextEdges: (field, mode) ->
        # field that should be checked to confinue search of next edge of blob
        if mode == 'top'
            return [
                ["#{ field.x+1 }-#{ field.y-1 }", 'left']
                ["#{ field.x+1 }-#{ field.y }", 'top']
                ["#{ field.x }-#{ field.y }", 'right']
            ]
        else if mode == 'right'
            return [
                ["#{ field.x+1 }-#{ field.y+1 }", 'top']
                ["#{ field.x }-#{ field.y+1 }", 'right']
                ["#{ field.x }-#{ field.y }", 'bottom']
            ]
        else if mode == 'bottom'
            return [
                ["#{ field.x-1 }-#{ field.y+1 }", 'right']
                ["#{ field.x-1 }-#{ field.y }", 'bottom']
                ["#{ field.x }-#{ field.y }", 'left']
            ]
        else if mode == 'left'
            return [
                ["#{ field.x-1 }-#{ field.y-1 }", 'bottom']
                ["#{ field.x }-#{ field.y-1 }", 'left']
                ["#{ field.x }-#{ field.y }", 'top']
            ]
        else
            throw new Error "Incorrect mode #{mode}!"

    getBlotPoints: (blot, padding=true) ->
        # gets all points of blob
        blotIds = {}
        for field in blot
            blotIds[field.id] = field

        # starts from first field - it should be highest field (lowest x), so there
        # will not be field more to the top, so draw top edge and go next
        field = blot[0]
        mode = 'top'
        points = @getEdge field, mode, padding

        # follow search of next edge of a blot until loop is closed
        foundNext = true
        while foundNext
            foundNext = false
            for [nextId, nextMode] in @getPossibleNextEdges field, mode
                if nextId == blot[0].id and nextMode == 'top'
                    # next edge is first edge - loop finished
                    # points.push points[0]
                    return points
                else if blotIds[nextId]?
                    field = blotIds[nextId]
                    mode = nextMode
                    points.push.apply points, @getEdge field, mode, padding
                    foundNext = true
                    break
            if not foundNext
                # this shouldn't happen - one of next edge should be matched!
                throw new Error "Broken blot!"

    constructor: (@blotId, @blots, @board) ->
        # find all verticles of blot
        outerPoints = @getBlotPoints(@blots[blotId])
        innerPoints = []

        # find which of other blots are inside
        for blot, i in @blots
            if i != @blotId
                for point in @getBlotPoints blot
                    if pointInPoly point, outerPoints
                        points = @getBlotPoints blot, padding=false
                        innerPoints.push points
                        break

        # draw polygon point by point - it's a set of lines and curves
        drawPolygon = (points, context) ->
            context.moveTo points[0].x, points[0].y
            # append to the end copy of first element so path starts and ends in the same point
            points.push points[0]
            for point, i in points
                if i > 0
                    lastPoint = points[i-1]
                    if lastPoint.x == point.x or lastPoint.y == point.y
                        # if same x or same y than it's a normal line
                        context.lineTo point.x, point.y
                    else
                        # calculate control point as a prolongation of last line
                        # so it check it was horizontal or vertical line
                        beforeLastPoint = points[i-2]
                        if beforeLastPoint.y == lastPoint.y
                            context.quadraticCurveTo point.x, lastPoint.y, point.x, point.y
                        else if beforeLastPoint.x == lastPoint.x
                            context.quadraticCurveTo lastPoint.x, point.y, point.x, point.y
                        else
                            throw new Error "Incorrect path!"

        # create shape
        @shape = new Kinetic.Shape
            sceneFunc: (context) ->
                # draw outside polygon - points are clockwise
                context.beginPath()
                drawPolygon outerPoints, context
                context.closePath()

                # draw inner polygons (holes) - points are counter-clockwise
                for points in innerPoints
                    points.reverse()
                    drawPolygon points, context
                    context.closePath()

                context.fillStrokeShape @

            fill: @colors[@blots[blotId][0].owner]

        @group = new Kinetic.Group
        @group.add @shape


class Renderer
    # Manage canvas and widgets
    board: null
    blotWidgets: []

    constructor: (@size, @board) ->
        @cavnasSize = Math.min(window.innerHeight, window.innerWidth) - 20

        @stage = new Kinetic.Stage
            container: 'wrap'
            width: @cavnasSize
            height: @cavnasSize

        # field widgets are created by field constructor
        # blot widgets have to be created here
        blots = @board.getBlots()
        for blot, blotId in blots
            if blot[0].owner != EMPTY
                blotWidget = new BlotWidget blotId, blots, @board
                @blotWidgets.push blotWidget

        @refreshWidgets()

        # add blots widgets to a layer
        @blotsLayer = new Kinetic.Layer
        for blotWidget in @blotWidgets
            @blotsLayer.add blotWidget.group
        @stage.add @blotsLayer

        # add fields widgets to a layer
        @fieldsLayer = new Kinetic.Layer
        for x in [0..@size-1]
            for y in [0..@size-1]
                @fieldsLayer.add @board.fields[x][y].widget.group
        @stage.add @fieldsLayer

    resizeCanvas: ->
        # adjust canvas size to window size
        @cavnasSize = Math.min(window.innerHeight, window.innerWidth) - 20
        @stage.setHeight @cavnasSize
        @stage.setWidth @cavnasSize

    refresh: ->
        @resizeCanvas()
        @refreshWidgets()

    getFieldCenter: (x, y) ->
        # calculate positions of a field widgets
        unit = Math.round(@cavnasSize / (@size*2))
        centerX = 2*unit + x*2*unit
        centerY = 2*unit + y*2*unit
        return [centerX-unit, centerY-unit]

    refreshWidgets: () ->
        # Resize and set positions of widgets
        unit = Math.round(@cavnasSize / (@size*2))

        for x in [0..@size-1]
            for y in [0..@size-1]
                [centerX, centerY] = @getFieldCenter x, y
                widget = @board.fields[x][y].widget
                widget.scale unit / 50
                widget.move centerX, centerY

        for widget in @blotWidgets
            widget.scale unit / 50


class Player
    id: null

    constructor: (@id) ->


class LocalPlayer extends Player



class AIPlayer extends Player



class Level
    players: null
    board: null

    constructor: (playersNo=2, boardSize=9) ->
        @board = new Board boardSize, playersNo
        @renderer = new Renderer boardSize, @board
        @players = [new LocalPlayer 0]
        for i in [1..@playersNo-1]
            @players.push new AIPlayer i


class Game
    levels_params: [
        [2, 6],
        [2, 7],
        [2, 8],
        [4, 8],
        [4, 9],
        [4, 10],
    ]
    level: null
    level_id: null

    constructor: () ->
        # TODO: get active level id from local storage
        @level_id = 0
        [playersNo, boardSize] = @levels_params[@level_id]
        @level = new Level playersNo, boardSize

window.game = game = new Game()
window.onresize = (event) -> game.level.renderer.refresh(event)
