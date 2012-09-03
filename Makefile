tests:
	@TESTING=true mocha \
		--reporter spec \
		--globals __PassiveRedis \
		--require should
