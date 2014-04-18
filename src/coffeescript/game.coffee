# blot vs. blot

EMPTY = 0
PLAYER_A = 1
PLAYER_B = 2
PLAYER_C = 3
PLAYER_D = 4


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
    colors: ['#cccccc', '#0099ff', '#cc0033', '#009900', '#ffff66']

    constructor: (field) ->
        @group = new Kinetic.Group

        @circle = new Kinetic.Circle {
            x: 0,
            y: 0,
            radius: 30,
            fill: @colors[field.owner],
        }
        @label = new Kinetic.Text {
            x: 0,
            y: 0,
            text: field.value,
            align: 'center',
            fontSize: 20,
            fontFamily: 'Calibri',
            fill: '#333333',

        }
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
        if (a+b < size) then ((a+b)*200+100) else ((2*(size-1)-a-b)*200+100)

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
                if field.owner != EMPTY and field.id not in visited
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
    #        gray        blue       red        green      yellow
    colors: ['#333333', '#0073bf', '#8c0023', '#005900', '#bfbf4d']

    move: (x, y) ->
        # to move widget to absolute position we have to calculate relative position
        # from current position
        relativeX = x - @group.x()
        relativeY = y - @group.y()
        @group.move {x: relativeX, y: relativeY}

    scale: (scale) ->
        # always scale with ration=1 (the same in both dimensions)
        @group.scale {x: scale, y: scale}

    getEdge: (field, mode) ->
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
        padding = 5
        cornerRadius = 20

        offsetX = field.x * edgeSize
        offsetY = field.y * edgeSize
        if mode == 'top'
            return [
                offsetX + padding + cornerRadius, offsetY + padding,
                offsetX + edgeSize - padding - cornerRadius, offsetY + padding,
            ]
        else if mode == 'right'
            return [
                offsetX + edgeSize - padding, offsetY + padding + cornerRadius,
                offsetX + edgeSize - padding, offsetY + edgeSize - padding - cornerRadius,
            ]

        else if mode == 'bottom'
            return [
                offsetX + edgeSize - padding - cornerRadius, offsetY + edgeSize - padding,
                offsetX + padding + cornerRadius, offsetY + edgeSize - padding,
            ]
        else if mode == 'left'
            return [
                offsetX + padding, offsetY + edgeSize - padding - cornerRadius,
                offsetX + padding, offsetY + padding + cornerRadius,
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

    getBlotPoints: () ->
        # gets all points of blob
        blotIds = {}
        for field in @blot
            blotIds[field.id] = field

        # starts from first field - it should be highest field (lowest x), so there
        # will not be field more to the top, so draw top edge and go next
        field = @blot[0]
        mode = 'top'
        points = @getEdge(field, mode)

        # follow search of next edge of a blot until loop is closed
        foundNext = true
        while foundNext
            foundNext = false
            for [nextId, nextMode] in @getPossibleNextEdges field, mode
                if nextId == @blot[0].id and nextMode == 'top'
                    # next edge is first edge - loop finished
                    return points
                else if blotIds[nextId]?
                    field = blotIds[nextId]
                    mode = nextMode
                    points.push.apply points, @getEdge(field, mode)
                    foundNext = true
                    break
            if not foundNext
                # this shouldn't happen - one of next edge should be matched!
                throw new Error "Broken blot!"

    constructor: (@blot, @board) ->

        points = @getBlotPoints()

        # create blob
        @shape = new Kinetic.Line {
            points: points,
            fill: @colors[@blot[0].owner],
            tension: 0.4,
            strokeEnabled: false
            lineCap: 'round'
            closed: true
        }

        @group = new Kinetic.Group
        @group.add @shape


class Renderer
    # Manage canvas and widgets
    board: null
    blotWidgets: []

    constructor: (@size, @board) ->
        @cavnasSize = Math.min(window.innerHeight, window.innerWidth) - 20

        @stage = new Kinetic.Stage {
            container: 'wrap',
            width: @cavnasSize,
            height: @cavnasSize
        }

        # field widgets are created by field constructor
        # blot widgets have to be created here
        for blot in @board.getBlots()
            blotWidget = new BlotWidget blot, @board
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
