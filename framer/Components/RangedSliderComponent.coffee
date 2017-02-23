Utils = require "../Utils"
{Layer} = require "../Layer"
{Events} = require "../Events"

"""
RangedSliderComponent

knob <layer>
knobSize <width, height>
fill <layer>
min <number>
max <number>
ranged <boolean>

pointForValue(<n>)
valueForPoint(<n>)

animateToValue(value, animationOptions={})
"""

Events.SliderValueChange  = "sliderValueChange"
Events.SliderMinValueChange = "sliderMinValueChange"
Events.SliderMaxValueChange = "sliderMaxValueChange"

class Knob extends Layer

	constructor: (options={}) ->
		_.defaults options,
			backgroundColor: "#fff"
			shadowY: 1,
			shadowBlur: 3
			shadowColor: "rgba(0, 0, 0, 0.35)"

		super options

	@define "constrained", @simpleProperty("constrained", false)

class exports.RangedSliderComponent extends Layer

	constructor: (options={}) ->

		_.defaults options,
			backgroundColor: "#ccc"
			borderRadius: 50
			clip: false
			width: 300
			height: 10
			value: 0
			knobSize: 30

		# Set some sensible default for the hit area
		options.hitArea ?= options.knobSize

		@leftKnob = new Knob
			name: "leftKnob"
			size: @knobSize or 30

		@rightKnob = new Knob
			name: "rightKnob"
			size: @knobSize or 30

		@fill = new Layer
			backgroundColor: "#333"
			width: 0
			force2d: true
			name: "fill"

		@sliderOverlay = new Layer
			backgroundColor: null
			name: "sliderOverlay"

		super options

		# Set fill initially
		if @width > @height
			@fill.height = @height
		else
			@fill.width = @width

		@fill.borderRadius = @sliderOverlay.borderRadius = @borderRadius
		@knobSize = options.knobSize

		@_styleKnob(@leftKnob)
		@_styleKnob(@rightKnob)
		@_updateFrame()
		@_updateKnob()
		@_updateFill()

		@on("change:frame", @_updateFrame)
		@on("change:borderRadius", @_setRadius)

		for knob in [@leftKnob, @rightKnob]
			knob.on("change:size", @_updateKnob)
			knob.on("change:frame", @_updateFill)
			knob.on("change:frame", @_knobDidMove)
			knob.on("change:frame", @_updateFrame)

		@sliderOverlay.on(Events.TapStart, @_touchStart)
		@sliderOverlay.on(Events.TapEnd, @_touchEnd)


	@define "ranged", @simpleProperty("ranged", false)

	_touchStart: (event) =>
		event.preventDefault()

		offsetX = (@min / @canvasScaleX()) - @min
		offsetY = (@min / @canvasScaleY()) - @min

		if @width > @height
			clickedValue = @valueForPoint(Events.touchEvent(event).clientX - @screenScaledFrame().x) / @canvasScaleX() - offsetX

			if clickedValue > @maxValue
				@maxValue = clickedValue
				@rightKnob.draggable._touchStart(event)

			if clickedValue < @minValue
				@minValue = clickedValue
				@leftKnob.draggable._touchStart(event)

		else
			@value = @valueForPoint(Events.touchEvent(event).clientY - @screenScaledFrame().y) / @canvasScaleY() - offsetY

		@_updateValue()

	_touchEnd: (event) =>
		@_updateValue()

	_styleKnob: (knob) =>
		knob.parent = @fill.parent = @sliderOverlay.parent = @
		knob.draggable.enabled = true
		knob.draggable.overdrag = false
		knob.draggable.momentum = true
		knob.draggable.momentumOptions = {friction: 5, tolerance: 0.25}
		knob.draggable.bounce = false
		knob.borderRadius = @knobSize / 2

	_updateFill: =>
		if @width > @height
			@fill.x = @leftKnob.midX
			@fill.width = @rightKnob.midX - @leftKnob.midX

		else
			@fill.height = @leftKnob.midY

	_updateKnob: =>
		if @width > @height

			@leftKnob.midX = @fill.x
			@leftKnob.centerY()

			@rightKnob.midX = @fill.x + @fill.width
			@rightKnob.centerY()

		else
			@leftKnob.midY = @fill.height
			@leftKnob.centerX()

	_updateFrame: =>

		@leftKnob.draggable.constraints =
			x: -@leftKnob.width / 2
			y: -@leftKnob.height / 2
			width: @rightKnob.midX
			height: @height + @leftKnob.height

		@rightKnob.draggable.constraints =
			x: @leftKnob.maxX
			y: -@rightKnob.height / 2
			width: @width + @rightKnob.width
			height: @height + @rightKnob.height

		# if knob.constrained
		# 	knob.draggable.constraints =
		# 		x: 0
		# 		y: 0
		# 		width: @width
		# 		height: @height

		@hitArea = @hitArea

		if @width > @height
			@fill.height = @height

			@leftKnob.midX = @pointForValue(@minValue)
			@rightKnob.midX = @pointForValue(@maxValue)
			@leftKnob.centerY()
		else
			@fill.width = @width
			@leftKnob.midY = @pointForValue(@value)
			@leftKnob.centerX()

		if @width > @height
			for knob in [@leftKnob, @rightKnob]
				knob.draggable.speedY = 0
				knob.draggable.speedX = 1
		else
			for knob in [@leftKnob, @rightKnob]
				knob.draggable.speedX = 0
				knob.draggable.speedY = 1

		@sliderOverlay.center()

	_setRadius: =>
		radius = @borderRadius
		@fill.style.borderRadius = "#{radius}px 0 0 #{radius}px"

	@define "knobSize",
		get: -> @_knobSize
		set: (value) ->

			for knob in [@leftKnob, @rightKnob]
				isRound = knob.borderRadius * 2 is @_knobSize
				@_knobSize = value
				knob.size = @_knobSize
				knob.borderRadius = @_knobSize / 2 if isRound

			@_updateFrame()

	@define "hitArea",
		get: ->
			@_hitArea
		set: (value) ->
			@_hitArea = value
			if @width > @height
				@sliderOverlay.width = @width + @hitArea
				@sliderOverlay.height = @hitArea
			else
				@sliderOverlay.width = @hitArea
				@sliderOverlay.height = @height + @hitArea


	@define "min",
		get: -> @_min or 0
		set: (value) -> @_min = value if _.isFinite(value)

	@define "max",
		get: -> @_max or 1
		set: (value) -> @_max = value if _.isFinite(value)

	@define "minValue",
		get: -> @_minValue or 0
		set: (value) ->
			return unless _.isFinite(value)
			@_minValue = value

			if @width > @height
				@leftKnob.midX = @pointForValue(value)
			else
				@leftKnob.midY = @pointForValue(value)

			@_updateFill()
			@_updateValue()

	@define "maxValue",
		get: -> @_maxValue or 0.5
		set: (value) ->
			return unless _.isFinite(value)
			@_maxValue = value

			if @width > @height
				@rightKnob.midX = @pointForValue(value)
			else
				@rightKnob.midY = @pointForValue(value)

			@_updateFill()
			@_updateValue()


	_knobDidMove: =>
		if @width > @height

			@minValue = @valueForPoint(@leftKnob.midX)
			@maxValue = @valueForPoint(@rightKnob.midX)
		else
			@value = @valueForPoint(@leftKnob.midY)

	_updateValue: =>

		# return if @_lastUpdatedMinValue is @minValue or @_lastUpdatedMaxValue is @maxValue
		#
		# @_lastUpdatedMinValue = @minValue
		# @_lastUpdatedMaxValue = @maxValue

		# @_range = [@minValue, @maxValue]

		@emit(Events.SliderValueChange)
		@emit(Events.SliderMinValueChange, @minValue)
		@emit(Events.SliderMaxValueChange, @maxValue)


	pointForValue: (value) ->
		for knob in [@leftKnob, @rightKnob]
			if @width > @height
				if knob.constrained
					return Utils.modulate(value, [@min, @max], [0 + (knob.width / 2), @width - (knob.width / 2)], true)
				else
					return Utils.modulate(value, [@min, @max], [0 , @width], true)
			else
				if knob.constrained
					return Utils.modulate(value, [@min, @max], [0 + (knob.height / 2), @height - (knob.height / 2)], true)
				else
					return Utils.modulate(value, [@min, @max], [0, @height], true)

	valueForPoint: (value) ->
		for knob in [@leftKnob, @rightKnob]
			if @width > @height
				if knob.constrained
					return Utils.modulate(value, [0 + (knob.width / 2), @width - (knob.width / 2)], [@min, @max], true)
				else
					return Utils.modulate(value, [0, @width], [@min, @max], true)
			else
				if knob.constrained
					return Utils.modulate(value, [0 + (knob.height / 2), @height - (knob.height / 2)], [@min, @max], true)
				else
					return Utils.modulate(value, [0, @height], [@min, @max], true)

	animateToMinValue: (value, animationOptions={curve: "spring(250, 25, 0)"}) ->
		return unless _.isFinite(value)
		if @width > @height
			animationOptions.properties = {x: @pointForValue(value) - (@leftKnob.width/2)}
		else
			animationOptions.properties = {y: @pointForValue(value) - (@leftKnob.height/2)}

		@leftKnob.animate(animationOptions)

	animateToMaxValue: (value, animationOptions={curve: "spring(250, 25, 0)"}) ->
		return unless _.isFinite(value)
		if @width > @height
			animationOptions.properties = {x: @pointForValue(value) - (@rightKnob.width/2)}
		else
			animationOptions.properties = {y: @pointForValue(value) - (@rightKnob.height/2)}

		@rightKnob.animate(animationOptions)
	##############################################################
	## EVENT HELPERS

	onValueChange: (cb) -> @on(Events.SliderValueChange, cb)
	onMinValueChange: (cb) -> @on(Events.SliderMinValueChange, cb)
	onMaxValueChange: (cb) -> @on(Events.SliderMaxValueChange, cb)
