Class {
	#name : 'ExtractedTypeForTmp',
	#superclass : 'ExtractedType',
	#instVars : [
		'compiledMethod'
	],
	#category : 'RoelTyper-Core',
	#package : 'RoelTyper',
	#tag : 'Core'
}

{ #category : 'instance creation' }
ExtractedTypeForTmp class >> forTmpOffset: offset ofCompiledMethod: aCompiledMethod inClass: aClass [
	^ self new 
		tempOffset: offset;
		ivarClass: aClass;
		compiledMethod: aCompiledMethod;
		yourself
]

{ #category : 'private-accessing' }
ExtractedTypeForTmp >> addAssignment: anObject [

	self haltIf: [
		compiledMethod selector = #nestedBlocksUsingOuterTemps and: [
			anObject = ByteString ] ].
	self assignments addIfNotPresent: anObject
]

{ #category : 'accessing' }
ExtractedTypeForTmp >> asBlockArgInTypeCollector: aTypeCollector [
	aTypeCollector transformAsBlockArg: self 
]

{ #category : 'accessing' }
ExtractedTypeForTmp >> compiledMethod [
	^ compiledMethod
]

{ #category : 'accessing' }
ExtractedTypeForTmp >> compiledMethod: anObject [
	compiledMethod := anObject
]

{ #category : 'accessing' }
ExtractedTypeForTmp >> tempOffset [
	^ivarName 
	
]

{ #category : 'accessing' }
ExtractedTypeForTmp >> tempOffset: anOffset [
	ivarName := anOffset
]
