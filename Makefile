#variable declarations
#sources
coffescript-dir = src/main/coffeescript
test-dir = src/test

#targets
build = target
core = $(build)/core
release = $(build)/release
browser-release = $(release)/browser
npm-release = $(release)/npm
tests = $(build)/tests
optimizations = $(tests)/optimizations
loaders = $(tests)/loaders
flattened-tests = $(tests)/flattened
hier-tests = $(tests)/hier

#this should be overridden when doing actual releases
release-number = $(shell git rev-parse HEAD)
#release stuff
module-name = scion
browser-release-module = $(browser-release)/$(module-name)-$(release-number).js
#TODO: this isn't used yet
npm-release-module = $(npm-release)/$(module-name)-$(release-number).tgz

#these modules are significant for building other components, such as tests, etc.
#TODO: use coffescript src names for these, and go through macro to convert them. More DRY
annotate-scxml-json-module = $(core)/util/annotate-scxml-json.js
runner-module = $(core)/runner.js
beautify-module = $(lib)/beautify.js
initializer-optimization-module = $(core)/optimization/initializer.js
class-optimization-module = $(core)/optimization/class.js
table-optimization-module = $(core)/optimization/state-table.js
switch-optimization-module = $(core)/optimization/switch.js

all : interpreter tests test-loader optimizations optimization-loaders 

#compile coffeescript
coffeescript-src = $(shell find $(coffescript-dir))
built-javascript-core = $(patsubst $(coffescript-dir)/%.coffee,$(core)/%.js, $(coffeescript-src))
$(core)/%.js : $(coffescript-dir)/%.coffee
	mkdir -p $(dir $@)
	coffee -o $(dir $@) $<

#copy over lib/js/*
lib-src = lib/js
lib-js-src = $(shell find $(lib-src)/*)
lib = $(core)/lib
lib-core = $(patsubst $(lib-src)/%,$(core)/lib/%, $(lib-js-src))

#copy over lib/requirejs/*
#these are core parts of requirejs which we depend on and need in order to build
requirejs-lib-src = lib/requirejs
requirejs-lib-js-src = $(shell find $(requirejs-lib-src)/* -name "*.js")
requirejs-lib-core = $(patsubst $(requirejs-lib-src)/%,$(core)/%, $(requirejs-lib-js-src))

#special requirejs module dependencies
#we can't use patterns easily here, so we just copy over targets
$(core)/logger.js : $(requirejs-lib-src)/logger.js
	mkdir -p $(dir $@)
	cp $< $@
	
$(core)/browser/print.js : $(requirejs-lib-src)/browser/print.js
	mkdir -p $(dir $@)
	cp $< $@

$(core)/env.js : $(requirejs-lib-src)/env.js
	mkdir -p $(dir $@)
	cp $< $@

$(core)/node/print.js : $(requirejs-lib-src)/node/print.js
	mkdir -p $(dir $@)
	cp $< $@

#copy over lib
$(lib)/% : $(lib-src)/%
	mkdir -p $(dir $@)
	cp $< $@

#build browser release module
$(browser-release-module) : $(built-javascript-core) $(lib-core) $(requirejs-lib-core)
	mkdir -p $(dir $@)
	r.js -o name=util/browser/parseOnLoad out=$(browser-release-module) baseUrl=$(core)

#npm package stuff

#copy over core
npm = $(build)/npm
npm-core = $(npm)/$(core)
npm-core-target = $(patsubst $(core)/%,$(npm-core)/%,$(built-javascript-core) $(lib-core) $(requirejs-lib-core))

$(npm-core)/% : $(core)/%
	mkdir -p $(dir $@)
	cp $< $@

#copy over relevant runner scripts
npm-src-scripts = src/test-scripts/run-module.sh src/test-scripts/annotate-scxml-json.sh src/main/bash/util/scxml-to-json.sh
npm-src-scripts-target = $(patsubst %.sh,$(npm)/%.sh,$(npm-src-scripts))

$(npm)/%.sh : %.sh
	mkdir -p $(dir $@)
	cp $< $@

#copy stuff to the root of the directory
npm-package-json-src = src/npm/package.json
npm-package-json-target = $(npm)/package.json

$(npm-package-json-target) : $(npm-package-json-src)
	mkdir -p $(dir $@)
	cp $< $@

#copy over lib 
#FIXME: lib should go over as-is in core, and get mapped using require.confg in runner.js
#cp -r lib/ target/npm/
lib-src-all = $(shell find lib/* -type f)
npm-lib = $(npm)/lib
npm-lib-target = $(patsubst lib/%,$(npm-lib)/%,$(lib-src-all))

$(npm-lib)/% : lib/%
	mkdir -p $(dir $@)
	cp $< $@

#generate tests
scxml-test-src = $(shell find $(test-dir) -name "*.scxml")
json-test-src = $(patsubst %.scxml,%.json,$(scxml-test-src))

#generate json from scxml
scxml-json-dir = $(tests)/scxml-json
scxml-json-tests = $(patsubst $(test-dir)/%.scxml, $(scxml-json-dir)/%.json, $(scxml-test-src)) 
$(scxml-json-dir)/%.json : $(test-dir)/%.scxml
	mkdir -p $(dir $@)
	./src/main/bash/util/scxml-to-json.sh $< > $@

#annotate it

annotated-scxml-json-dir = $(tests)/annotated-scxml-json
annotated-scxml-json-tests = $(patsubst $(scxml-json-dir)/%.json,$(annotated-scxml-json-dir)/%.json,$(scxml-json-tests)) 
$(annotated-scxml-json-dir)/%.json : $(tests)/scxml-json/%.json $(annotate-scxml-json-module) $(runner-module)
	mkdir -p $(dir $@)
	./src/test-scripts/run-module-node.sh util/annotate-scxml-json $< $@

#annotated-scxml-json-tests : $(annotated-scxml-json-tests)

#combine it with the json test script
#in this task, $^ are all the dependencies, second arg is the test name, third arg is the test group name
combined-script-and-annotated-scxml-json-dir = $(tests)/combined-script-and-annotated-scxml-json-test
combined-script-and-annotated-scxml-json-test = $(patsubst $(annotated-scxml-json-dir)/%.json,$(combined-script-and-annotated-scxml-json-dir)/%.js,$(annotated-scxml-json-tests)) 
$(combined-script-and-annotated-scxml-json-dir)/%.js : $(annotated-scxml-json-dir)/%.json $(test-dir)/%.json
	mkdir -p $(dir $@)
	./src/main/bash/build/generate-requirejs-json-test-tuples.sh $^ "$(basename $(notdir $<))" "$(notdir $(shell dirname $<))" > $@

#generate spartan loader
generate-test-loader-module-script = src/main/bash/build/generate-requirejs-test-loader-module.sh
$(loaders)/spartan-loader-for-all-tests.js :
	mkdir -p $(dir $@)
	$(generate-test-loader-module-script) $@ $(combined-script-and-annotated-scxml-json-test)

#generate optimizations
transition-selector = $(optimizations)/transition-selector

#class, switch, and table transition selectors
class-transition-selector = $(patsubst $(annotated-scxml-json-dir)/%.json,$(transition-selector)/%.class.js,$(annotated-scxml-json-tests))
switch-transition-selector = $(patsubst $(annotated-scxml-json-dir)/%.json,$(transition-selector)/%.switch.js,$(annotated-scxml-json-tests))
table-transition-selector = $(patsubst $(annotated-scxml-json-dir)/%.json,$(transition-selector)/%.table.js,$(annotated-scxml-json-tests))

$(transition-selector)/%.class.js : $(annotated-scxml-json-dir)/%.json $(runner-module) $(beautify-module) $(initializer-optimization-module) $(class-optimization-module)
	mkdir -p $(dir $@)
	./src/test-scripts/run-module-node.sh optimization/transition-optimizer $< class true true > $@

$(transition-selector)/%.switch.js : $(annotated-scxml-json-dir)/%.json $(runner-module) $(beautify-module) $(initializer-optimization-module) $(switch-optimization-module)
	mkdir -p $(dir $@)
	./src/test-scripts/run-module-node.sh optimization/transition-optimizer $< switch true true > $@

$(transition-selector)/%.table.js : $(annotated-scxml-json-dir)/%.json $(runner-module) $(beautify-module) $(initializer-optimization-module) $(table-optimization-module)
	mkdir -p $(dir $@)
	./src/test-scripts/run-module-node.sh optimization/transition-optimizer $< table true true > $@


generate-array-test-loader-module-script = src/main/bash/build/generate-requirejs-array-test-loader-module.sh

#generate optimization loader modules
$(loaders)/class-transition-lookup-optimization-loader.js : 
	mkdir -p $(dir $@)
	$(generate-test-loader-module-script) $@ $(class-transition-selector)
	
$(loaders)/table-transition-lookup-optimization-loader.js : 
	mkdir -p $(dir $@)
	$(generate-test-loader-module-script) $@ $(table-transition-selector)

$(loaders)/switch-transition-lookup-optimization-loader.js : 
	mkdir -p $(dir $@)
	$(generate-test-loader-module-script) $@ $(switch-transition-selector)

$(loaders)/class-transition-lookup-optimization-array-loader.js : 
	mkdir -p $(dir $@)
	$(generate-array-test-loader-module-script) $@ $(class-transition-selector)
	
$(loaders)/table-transition-lookup-optimization-array-loader.js : 
	mkdir -p $(dir $@)
	$(generate-array-test-loader-module-script) $@ $(table-transition-selector)

$(loaders)/switch-transition-lookup-optimization-array-loader.js : 
	mkdir -p $(dir $@)
	$(generate-array-test-loader-module-script) $@ $(switch-transition-selector)


#top-level tasks
#TODO: node module
#TODO: flattened test modules
#TODO: all test modules

#interpreter
interpreter : $(built-javascript-core) $(lib-core)

#amd module
browser-release : $(browser-release-module)

#npm package
npm-package : $(npm-core-target) $(npm-src-scripts-target) $(npm-package-json-target) $(npm-lib-target)

#test modules
tests : $(combined-script-and-annotated-scxml-json-test)

#test-loader	(with/without flattened test modules)
test-loader : $(loaders)/spartan-loader-for-all-tests.js

#optimizations
optimizations : $(class-transition-selector) $(table-transition-selector) $(switch-transition-selector) 

#optimization-loaders	(with/without flattened test modules)
optimization-loaders : $(loaders)/class-transition-lookup-optimization-loader.js $(loaders)/table-transition-lookup-optimization-loader.js $(loaders)/switch-transition-lookup-optimization-loader.js $(loaders)/class-transition-lookup-optimization-array-loader.js $(loaders)/table-transition-lookup-optimization-array-loader.js $(loaders)/switch-transition-lookup-optimization-array-loader.js

get-deps :
	npm install -g coffee requirejs


foo : 
	echo $(npm-src-scripts-target)

clean : 
	rm -rf $(build)


.SECONDARY : $(scxml-json-tests) $(annotated-scxml-json-tests)
.PHONY : interpreter browser-release npm-package tests optimzations test-loader optimization-loaders get-deps clean foo
