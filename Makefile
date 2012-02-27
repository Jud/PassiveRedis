tests:
		@mocha \
			--reporter spec \
			--globals User,Cog \
			--require should
