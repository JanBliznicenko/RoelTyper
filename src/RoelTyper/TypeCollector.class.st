"
I collect and assemble the types sent to instance variables for a certain class (I use the InterfaceExtractor for that), and use them to create and return TypingResults.

Instance Variables:
	assignments	<Object>	description of assignments
	instVarOffset	<Object>	description of instVarOffset
	instVars	<(Palette of: (ExceptionSet | GenericException | SequenceableCollection | Signal)) | (SequenceableCollection of: (ExceptionSet | GenericException | SequenceableCollection | Signal))>	description of instVars
	sends	<Object>	description of sends
	theClass	<ClassDescription>	description of theClass
			

Our type-reconstruction algorithm can be decomposed into three phases:

	1. interface type extraction. This phase reconstructs the types according to the messages that are being sent to the variable in the class where it is defined. This is done in two steps: first of all the set of messages sent to the variable is collected. Secondly we look through the system and find all types that understand this set of selectors. The output of this phase are the interface types.

	2. assignment type extraction. This phase reconstructs the types by looking at assignments made to the variable in the class where it is defined. It collects all right-hand sides of assign- ment expressions involving the variable, and applies a series of heuristics to find the type results of these expressions. These are then collected in the assignment types.

	3. merging. This phase takes the interface types and the assignment types as input, and merges them into the final type results for the variable.
"
Class {
	#name : 'TypeCollector',
	#superclass : 'Object',
	#instVars : [
		'theClass',
		'instVars',
		'typingResults',
		'currentExtractedMethod',
		'localTypingResults'
	],
	#category : 'RoelTyper-Core',
	#package : 'RoelTyper',
	#tag : 'Core'
}

{ #category : 'instance creation' }
TypeCollector class >> collectorAfterTypeInstvarsOfClass: aClass [
	"self typeInstvarsOfClass: Point"

	^self new typeInstvarsOfClass: aClass; yourself
]

{ #category : 'instance creation' }
TypeCollector class >> new [
	"Override new to return either a VWTypeCollector or a SqueakTypeCollector"

	^self newForPlatform
]

{ #category : 'instance creation' }
TypeCollector class >> newForPlatform [
	"Return either one of my subclass instance depending on the platform used."

	^ PharoTypeCollector basicNew
]

{ #category : 'instance creation' }
TypeCollector class >> onClass: aClass [

	^ self new onClass: aClass
]

{ #category : 'instance creation' }
TypeCollector class >> typeInstvar: var ofClass: aClass [
	"self typeInstvar: #x ofClass: Point "

	^(self new typeInstvarsOfClass: aClass) at: var
]

{ #category : 'instance creation' }
TypeCollector class >> typeInstvar: var ofClassWithLookup: aClass [ 
	"self typeInstvar: #origin ofClassWithLookup: Quadrangle"
	| theClass |
	theClass := aClass.
	[theClass isNil not
		and: [theClass instVarNames includes: var]]
		whileFalse: [theClass := theClass superclass].
	theClass isNil
		ifTrue: [^ ExtractedType new].
	^ self typeInstvar: var ofClass: theClass
]

{ #category : 'instance creation' }
TypeCollector class >> typeInstvarsOfClass: aClass [
	"self typeInstvarsOfClass: Point"

	^self new typeInstvarsOfClass: aClass
]

{ #category : 'instance creation' }
TypeCollector class >> typeTmpsIn: aCompiledMethod [
	"self typeTmpsIn: Point>>#angleWith: ofClass: Point"

	^ self
		  typeTmpsIn: aCompiledMethod
		  ofClass: aCompiledMethod methodClass
]

{ #category : 'instance creation' }
TypeCollector class >> typeTmpsIn: aCompiledMethod ofClass: aClass [
	"self typeTmpsIn: Point>>#angleWith: ofClass: Point"

	^ self new typeTmpsIn: aCompiledMethod ofClass: aClass
]

{ #category : 'instance creation' }
TypeCollector class >> typeTmpsInSelector: aSelector ofClass: aClass [
	"self typeTmpsIn: Point>>#angleWith: ofClass: Point"

	^ self typeTmpsIn: aClass >> aSelector ofClass: aClass
]

{ #category : 'instance creation' }
TypeCollector class >> versionString [
	"Take the removal of the standard version method on Smalltalk into account for Squeak :-( "

	^(Smalltalk
		at: #SystemVersion
		ifAbsent: [^Smalltalk version]) current version
]

{ #category : 'accessing' }
TypeCollector >> absoluteIndexForVar: iVar [
	"Note: works for Squeak and VisualWorks. If it would be only for VW, you could just use instVarIndexFor: instead."

	^instVars indexOf: iVar
]

{ #category : 'adding' }
TypeCollector >> addAssignment: value to: index [
	self
		withTranslatedIndex: index
		do: [ :i | (self typingResults at: i) addAssignment: value ]
]

{ #category : 'adding' }
TypeCollector >> addAssignment: val toReturnOf: aSelector [  
	| eT |
	eT := self extractedTypeForReturnInMethod: (theClass >> aSelector).
	eT addAssignment: val.
]

{ #category : 'adding' }
TypeCollector >> addAssignment: value toTmp: index [

	^ self addAssignment: value toTmp: index in: currentExtractedMethod
]

{ #category : 'adding' }
TypeCollector >> addAssignment: value toTmp: index in: aCompiledMethod [

	(self localTypingResultOf: aCompiledMethod index: index)
		addAssignment: value
]

{ #category : 'adding' }
TypeCollector >> addAssignmentForReturn: val [

	| eT |
	eT := self extractedTypeForReturnInMethod: currentExtractedMethod.
	val isInteger
		ifTrue: [
			self
				withTranslatedIndex: val
				do: [ :idx |
				eT addReverseLinkedExtractedType: (typingResults at: idx) ] ]
		ifFalse: [
			(val isVariableBinding and: [ val key = #temp ])
				ifTrue: [
					eT addReverseLinkedExtractedType:
						(self
							 localTypingResultOf: currentExtractedMethod
							 index: val value) ]
				ifFalse: [
					(val isVariableBinding and: [ val key = #return ])
						ifTrue: [
							eT addReverseLinkedExtractedType:
								(self extractedTypeForReturnInMethod: theClass >> val value) ]
						ifFalse: [
							(val isVariableBinding and: [ val key = #blockArg ])
								ifTrue: [  ]
								ifFalse: [
									(self assignmentTypeOf: val) ifNotNil: [ :result |
										eT addAssignment: result ] ] ] ] ]
]

{ #category : 'adding' }
TypeCollector >> addAssignmentForReturnSelf [
	(self extractedTypeForReturnInMethod: currentExtractedMethod) addAssignment: theClass
]

{ #category : 'initialize-release' }
TypeCollector >> addLocalTypingResultsFor: aCompiledCode [

	localTypingResults
		at: aCompiledCode
		put:
			((1 to: aCompiledCode sourceNode allOwnTempNames size + 1)
				 collect: [ :each |
					 ExtractedTypeForTmp
						 forTmpOffset: each
						 ofCompiledMethod: aCompiledCode
						 inClass: aCompiledCode methodClass ]) asArray
]

{ #category : 'adding' }
TypeCollector >> addSend: selector onReturnOfSelfMethod: aSelfSelector [
	"Add a range check to filter out sends to instvars defined in superclasses, etc."
	(self extractedTypeForReturnInMethod: theClass >> aSelfSelector) addSend: selector
]

{ #category : 'adding' }
TypeCollector >> addSend: selector to: index [
	"Add a range check to filter out sends to instvars defined in superclasses, etc."

	self
		withTranslatedIndex: index
		do: [:i | (self typingResults at: i) addSend: selector]
]

{ #category : 'adding' }
TypeCollector >> addSend: selector toTmp: index [
	"Add a range check to filter out sends to instvars defined in superclasses, etc."

	(self localTypingResultOf: currentExtractedMethod index: index)
		addSend: selector
]

{ #category : 'accessing' }
TypeCollector >> allInstVarTypes [
	self typingResults do: [ :each | each types ]
	
]

{ #category : 'accessing' }
TypeCollector >> allTmpTypes [

	localTypingResults valuesDo: [ :array | array do: [ :et | et types]]
]

{ #category : 'accessing' }
TypeCollector >> allTypes [
	self typingResults do: [ :each | each types ].
	localTypingResults valuesDo: [ :array | array do: [ :et | et types ]]
]

{ #category : 'heuristics' }
TypeCollector >> assignmentTypeOf: val [
	^self subclassResponsibility
]

{ #category : 'accessing' }
TypeCollector >> assignmentsTo: instVarName [
	^ (self typingResultsFor: instVarName) flattenLinks; assignments
]

{ #category : 'accessing' }
TypeCollector >> currentExtractedMethod [
	^ currentExtractedMethod
]

{ #category : 'accessing' }
TypeCollector >> currentExtractedMethod: anObject [

	currentExtractedMethod := anObject.
	self addLocalTypingResultsFor: anObject
]

{ #category : 'public-typing' }
TypeCollector >> extractClass: aClass [

	| extractor |
	self onClass: aClass.
	extractor := self newExtractor.

	aClass methodsDo: [ :method |
		currentExtractedMethod := method.
		extractor extractInterfacesFrom: method addTo: self ].

	^ extractor
]

{ #category : 'public-typing' }
TypeCollector >> extractClass: aClass withExtraMethod: aCompiledMethod [

	"The extra method must belong to the same class, but does not have to be installed (and even the installed version might exist along side of it). Still usable with installed method as well."

	| extractor |
	extractor := self extractClass: aClass.
	self addLocalTypingResultsFor: aCompiledMethod.

	currentExtractedMethod := aCompiledMethod.
	extractor extractInterfacesFrom: aCompiledMethod addTo: self.
]

{ #category : 'adding' }
TypeCollector >> extractedTypeForReturnInMethod: aCompiledMethod [
	^(localTypingResults at: aCompiledMethod) last
]

{ #category : 'heuristics' }
TypeCollector >> handleAssignment: val for: index [

	val isInteger
		ifTrue: [
			self withTranslatedIndex: val do: [ :idx |
				(typingResults at: index + 1) addReverseLinkedExtractedType:
					(typingResults at: idx) ] ]
		ifFalse: [
			(val isVariableBinding and: [ val key = #temp ])
				ifTrue: [
					(typingResults at: index + 1) addReverseLinkedExtractedType:
						(self
							 localTypingResultOf: currentExtractedMethod
							 index: val value) ]
				ifFalse: [
					(val isVariableBinding and: [ val key = #return ])
						ifTrue: [
							(typingResults at: index + 1) addReverseLinkedExtractedType:
								(self extractedTypeForReturnInMethod: theClass >> val value) ]
						ifFalse: [
							(val isVariableBinding and: [ val key = #blockArg ]) ifFalse: [
								(self assignmentTypeOf: val) ifNotNil: [ :result |
									self addAssignment: result to: index ] ] ] ] ]
]

{ #category : 'heuristics' }
TypeCollector >> handleAssignment: val forTmp: index [

	^ self handleAssignment: val forTmp: index in: currentExtractedMethod
]

{ #category : 'heuristics' }
TypeCollector >> handleAssignment: val forTmp: index in: aCompiledMethod [
	"Cannot use ifNotNil: with argument in Squeak, so use a temporary instead."

	val isInteger
		ifTrue: [
			self withTranslatedIndex: val do: [ :idx |
				(self localTypingResultOf: aCompiledMethod index: index)
					addReverseLinkedExtractedType: (typingResults at: idx) ] ]
		ifFalse: [
			(val isVariableBinding and: [ val key = #temp ])
				ifTrue: [
					(self localTypingResultOf: aCompiledMethod index: index)
						addReverseLinkedExtractedType:
						(self
							 localTypingResultOf: currentExtractedMethod
							 index: val value) ]
				ifFalse: [
					(val isVariableBinding and: [ val key = #return ])
						ifTrue: [
							(self localTypingResultOf: aCompiledMethod index: index)
								addReverseLinkedExtractedType:
								(self extractedTypeForReturnInMethod: theClass >> val value) ]
						ifFalse: [
							(val isVariableBinding and: [ val key = #blockArg ]) ifFalse: [
								(self assignmentTypeOf: val) ifNotNil: [ :result |
									self addAssignment: result toTmp: index in: aCompiledMethod ] ] ] ] ]
]

{ #category : 'private' }
TypeCollector >> indexInListForMethod: aCompiledMethod index: index [

	index < 0 ifTrue: [
		^ aCompiledMethod ast scope tempVarNames size - index ].
	^ index + 1
]

{ #category : 'heuristics' }
TypeCollector >> languageSpecificPushSendOf: selector to: rec args: args [
	^#computed
]

{ #category : 'private' }
TypeCollector >> localTypingResultOf: aMethod index: index [

	^ (localTypingResults at: aMethod) at:
		  (self indexInListForMethod: aMethod index: index)
]

{ #category : 'private' }
TypeCollector >> newExtractor [
	"Return a new extractor class. This is typically Smalltalk dialect dependent, so subclasses have to override to choose the one they want."

	^self subclassResponsibility
]

{ #category : 'initialize-release' }
TypeCollector >> onClass: aClass [

	theClass := aClass.
	instVars := aClass allInstVarNames collect: [ :e | e asSymbol ].
	typingResults := (instVars collect: [ :ivar |
		                  ExtractedType forInstvar: ivar inClass: aClass ])
		                 asArray.
	localTypingResults := Dictionary new.
	theClass selectorsAndMethodsDo: [ :sel :cm |
		self addLocalTypingResultsFor: cm ]
]

{ #category : 'accessing' }
TypeCollector >> packagedResults [

	| results |
	results := IdentityDictionary new.
	instVars size - theClass instVarNames size + 1 to: instVars size do: [
		:index |
		results at: (instVars at: index) put: (self typingResults at: index) ].
	localTypingResults keysDo: [ :eachMethod |
		| prefix |
		prefix := '_' , eachMethod selector , '>>'.
		(self packagedResultsForCompiledMethod: eachMethod)
			keysAndValuesDo: [ :eachName :eachExtractedType |
				results at: (prefix , eachName) asSymbol put: eachExtractedType ] ].

	^ results
]

{ #category : 'accessing' }
TypeCollector >> packagedResultsForCompiledMethod: aCompiledMethod [

	| results arr i |
	results := IdentityDictionary new.
	arr := localTypingResults at: aCompiledMethod.

	i := 0.
	aCompiledMethod sourceNode allOwnTempNamesByOwners withIndexDo: [
		:ownerWithListOfVarNames
		:methodOrBlockIndex |
		| prefix |
		prefix := methodOrBlockIndex = 1
			          ifTrue: [ '' ]
			          ifFalse: [
			          '_block' , (methodOrBlockIndex - 1) asString , '->' ].
		ownerWithListOfVarNames value do: [ :eachVarName |
			i := i + 1.
			results at: (prefix , eachVarName) asSymbol put: (arr at: i) ] ].
	results at: #'^' put: arr last.

	^ results
]

{ #category : 'heuristics' }
TypeCollector >> pushSendOf: selector to: rec args: args [
	"Needs to be optimized"

	| index recValue |
	rec == #self ifTrue: [
		(index := instVars indexOf: selector) > 0 ifTrue: [ ^ index - 1 ].
		(selector last == $: and: [
			 (index := instVars indexOf:
				           (selector copyFrom: 1 to: selector size - 1)) > 0 ])
			ifTrue: [
				self handleAssignment: args first for: index - 1.
				^ #result -> selector ] ].

	(#( #= #'==' #< #> #'<=' #'>=' #'~=' #'~~' #notNil #xor: ) includes:
		 selector) ifTrue: [ ^ Boolean ].

	((selector at: 1 ifAbsent: [ $j ]) = $i and: [
		 (selector at: 2 ifAbsent: [ $j ]) = $s and: [
			 (selector at: 3 ifAbsent: [ $n ]) isLowercase not ] ]) ifTrue: [
		^ Boolean ].

	rec isVariableBinding ifTrue: [
		((recValue := rec value) isBehavior and: [
			 (recValue class categoryForSelector: selector)
			 == #'instance creation' ]) ifTrue: [
			^ Association key: #instcreation value: recValue ] ].

	^ self languageSpecificPushSendOf: selector to: rec args: args
]

{ #category : 'accessing' }
TypeCollector >> sendsTo: instVarName [

	^ (self typingResultsFor: instVarName) interface
]

{ #category : 'initialize-release' }
TypeCollector >> theClass [
	^theClass
]

{ #category : 'adding' }
TypeCollector >> transformAsBlockArg: anExtractedTypeForTmp [

	(localTypingResults at: anExtractedTypeForTmp compiledMethod)
		at: anExtractedTypeForTmp tempOffset
		put: (ExtractedTypeForBlockArg
				 forOffset: anExtractedTypeForTmp tempOffset
				 ofCompiledMethod: anExtractedTypeForTmp compiledMethod
				 inClass: anExtractedTypeForTmp ivarClass)
]

{ #category : 'adding' }
TypeCollector >> transformAsBlockArgTheTmpOffset: offset [

	^ self
		  transformAsBlockArgTheTmpOffset: offset
		  in: currentExtractedMethod
]

{ #category : 'adding' }
TypeCollector >> transformAsBlockArgTheTmpOffset: offset in: aCompiledMethod [

	(self localTypingResultOf: aCompiledMethod index: offset)
		asBlockArgInTypeCollector: self
]

{ #category : 'private' }
TypeCollector >> tryUsing: receiver for: selector ifNotUse: aClass [
	"If receiver has a type, and the selector is understood by that type, pass that type. If not, use aClass as type."

	| cl |
	cl := self assignmentTypeOf: receiver.
	^(cl notNil and: [cl methodDict includesKey: selector])
		ifTrue: [ cl ]
		ifFalse: [ aClass ]
]

{ #category : 'public-typing' }
TypeCollector >> typeInstvarsOfClass: aClass [

	self extractClass: aClass.
	^ self packagedResults
]

{ #category : 'public-typing' }
TypeCollector >> typeTmpsIn: aCompiledMethod ofClass: aClass [

	self extractClass: aClass withExtraMethod: aCompiledMethod.
	^ self packagedResultsForCompiledMethod: aCompiledMethod
]

{ #category : 'accessing' }
TypeCollector >> typingResults [
	^ typingResults
]

{ #category : 'private' }
TypeCollector >> typingResultsFor: instVarName [
	^self typingResults at: (self absoluteIndexForVar: instVarName)
]

{ #category : 'private' }
TypeCollector >> withTranslatedIndex: index do: aBlock [
	aBlock value: index + 1
]
