/*
 * RequestManager+CoreData.swift
 * BMO+CoreData
 *
 * Created by François Lamboley on 1/30/17.
 * Copyright © 2017 happn. All rights reserved.
 */

import CoreData
import Foundation
import os.log

import AsyncOperationResult

import BMO
import BMO_RESTUtils



extension RequestManager {
	
	/* **********************
	   MARK: - Fetch Requests
	   ********************** */
	
	/* **********************************************************
	   MARK: → Retrieving objects before and after back operation
	   ********************************************************** */
	
	/** Fetch **one** object of the given type. If ever there were more than one
	object matching the given id, the first is returned and a warning is printed
	in the logs. (If there are no remoteId given, there must be one object of the
	given entity in the db.)
	
	Does **not** throw. If an error occurred fetching the object from Core Data,
	the error will silently be ignored and the returned object will be `nil`.
	
	The handler (if any) is called **on the context**.
	
	The handler _might_ be called before the function returns (in case there is a
	problem creating the back operations for instance). */
	@available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *)
	public func unsafeFetchObject<BridgeType, ObjectType: NSManagedObject>(
		withRemoteId remoteId: String?, flatifiedFields: String? = nil, keyPathPaginatorInfo: [String: Any]? = nil, remoteIdAttributeName: String = "remoteId",
		fetchType: CoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: BridgeType? = nil,
		handler: ((_ fetchedObject: ObjectType?, _ fullResponse: AsyncOperationResult<BridgeBackRequestResult<BridgeType>>) -> Void)? = nil
	) -> (fetchedObject: ObjectType?, operation: BackRequestOperation<CoreDataFetchRequest, BridgeType>)
	{
		return unsafeFetchObject(ofEntity: ObjectType.entity(), withRemoteId: remoteId, flatifiedFields: flatifiedFields, keyPathPaginatorInfo: keyPathPaginatorInfo, remoteIdAttributeName: remoteIdAttributeName, fetchType: fetchType, onContext: context, bridge: bridge, handler: handler)
	}
	
	/* iOS 8 & 9 version of the method above. */
	public func unsafeFetchObject<BridgeType, ObjectType: NSManagedObject>(
		ofEntity entity: NSEntityDescription, withRemoteId remoteId: String?, flatifiedFields: String? = nil, keyPathPaginatorInfo: [String: Any]? = nil, remoteIdAttributeName: String = "remoteId",
		fetchType: CoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: BridgeType? = nil,
		handler: ((_ fetchedObject: ObjectType?, _ fullResponse: AsyncOperationResult<BridgeBackRequestResult<BridgeType>>) -> Void)? = nil
	) -> (fetchedObject: ObjectType?, operation: BackRequestOperation<CoreDataFetchRequest, BridgeType>)
	{
		/* Creating the fetch request */
		let fetchRequest = RequestManager.fetchRequestForFetchingObject(ofEntity: entity, withRemoteId: remoteId, remoteIdAttributeName: remoteIdAttributeName)
		
		/* Retrieving the object */
		let object = (try? context.fetch(fetchRequest))?.first as! ObjectType?
		#if DEBUG
			if let c = try? context.count(for: fetchRequest), c > 1 {
				if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("Got %d results where at most 1 was expected.", log: $0, type: .info, c) }}
				else                                                          {NSLog("Got %d results where at most 1 was expected.", c)}
			}
		#endif
		
		/* Creating and running the operation */
		return (fetchedObject: object, operation: fetchObject(fromFetchRequest: fetchRequest, withFlatifiedFields: flatifiedFields, keyPathPaginatorInfo: keyPathPaginatorInfo, fetchType: fetchType, onContext: context, bridge: bridge, handler: handler))
	}
	
	public func unsafeFetchObject<BridgeType, ObjectType: NSManagedObject>(
		fromFetchRequest fetchRequest: NSFetchRequest<NSFetchRequestResult>, additionalRequestInfo: AdditionalRESTRequestInfo<NSPropertyDescription>?,
		fetchType: CoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: BridgeType? = nil,
		handler: ((_ fetchedObject: ObjectType?, _ fullResponse: AsyncOperationResult<BridgeBackRequestResult<BridgeType>>) -> Void)? = nil
	) -> (fetchedObject: ObjectType?, operation: BackRequestOperation<CoreDataFetchRequest, BridgeType>)
	{
		/* Retrieving the object */
		let object = (try? context.fetch(fetchRequest))?.first as! ObjectType?
		#if DEBUG
			if let c = try? context.count(for: fetchRequest), c > 1 {
				if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("Got %d results where at most 1 was expected.", log: $0, type: .info, c) }}
				else                                                          {NSLog("Got %d results where at most 1 was expected.", c)}
			}
		#endif
		
		/* Creating and running the operation */
		return (fetchedObject: object, operation: fetchObject(fromFetchRequest: fetchRequest, additionalRequestInfo: additionalRequestInfo, fetchType: fetchType, onContext: context, bridge: bridge, handler: handler))
	}
	
	/** Fetch objects fulfilling the given fetch request.
	
	Does **not** throw. If an error occurred fetching the objects from Core Data,
	the error will silently be ignored and the returned objects will be `[]`.
	
	The handler (if any) is called **on the context**.
	
	The handler _might_ be called before the function returns (in case there is a
	problem creating the back operations for instance). */
	public func unsafeFetchObjects<BridgeType, ObjectType: NSManagedObject>(
		fromFetchRequest fetchRequest: NSFetchRequest<NSFetchRequestResult>, withFlatifiedFields flatifiedFields: String? = nil, paginatorInfo: Any? = nil,
		fetchType: CoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: BridgeType? = nil,
		handler: ((_ fetchedObjects: [ObjectType], _ response: AsyncOperationResult<BridgeBackRequestResult<BridgeType>>) -> Void)? = nil
	) -> (fetchedObjects: [ObjectType], operation: BackRequestOperation<CoreDataFetchRequest, BridgeType>)
	{
		let objects = (try? context.fetch(fetchRequest)) as! [ObjectType]? ?? []
		return (fetchedObjects: objects, operation: fetchObjects(fromFetchRequest: fetchRequest, withFlatifiedFields: flatifiedFields, paginatorInfo: paginatorInfo, fetchType: fetchType, onContext: context, bridge: bridge, handler: handler))
	}
	
	/* ***********************************************
	   MARK: → Retrieving objects after back operation
	   *********************************************** */
	
	@discardableResult
	@available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *)
	public func fetchObject<BridgeType, ObjectType: NSManagedObject>(
		withRemoteId remoteId: String?, flatifiedFields: String? = nil, keyPathPaginatorInfo: [String: Any]? = nil, remoteIdAttributeName: String = "remoteId",
		fetchType: CoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: BridgeType? = nil,
		handler: ((_ fetchedObject: ObjectType?, _ fullResponse: AsyncOperationResult<BridgeBackRequestResult<BridgeType>>) -> Void)? = nil
	) -> BackRequestOperation<CoreDataFetchRequest, BridgeType>
	{
		return fetchObject(ofEntity: ObjectType.entity(), withRemoteId: remoteId, flatifiedFields: flatifiedFields, keyPathPaginatorInfo: keyPathPaginatorInfo, remoteIdAttributeName: remoteIdAttributeName, fetchType: fetchType, onContext: context, bridge: bridge, handler: handler)
	}
	
	@discardableResult
	public func fetchObject<BridgeType, ObjectType: NSManagedObject>(
		ofEntity entity: NSEntityDescription, withRemoteId remoteId: String?, flatifiedFields: String? = nil, keyPathPaginatorInfo: [String: Any]? = nil, remoteIdAttributeName: String = "remoteId",
		fetchType: CoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: BridgeType? = nil,
		handler: ((_ fetchedObject: ObjectType?, _ fullResponse: AsyncOperationResult<BridgeBackRequestResult<BridgeType>>) -> Void)? = nil
	) -> BackRequestOperation<CoreDataFetchRequest, BridgeType>
	{
		let fetchRequest = RequestManager.fetchRequestForFetchingObject(ofEntity: entity, withRemoteId: remoteId, remoteIdAttributeName: remoteIdAttributeName)
		return fetchObject(fromFetchRequest: fetchRequest, withFlatifiedFields: flatifiedFields, keyPathPaginatorInfo: keyPathPaginatorInfo, fetchType: fetchType, onContext: context, bridge: bridge, handler: handler)
	}
	
	@discardableResult
	public func fetchObject<BridgeType, ObjectType: NSManagedObject>(
		fromFetchRequest fetchRequest: NSFetchRequest<NSFetchRequestResult>, withFlatifiedFields flatifiedFields: String? = nil, keyPathPaginatorInfo: [String: Any]? = nil,
		fetchType: CoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: BridgeType? = nil,
		handler: ((_ fetchedObject: ObjectType?, _ fullResponse: AsyncOperationResult<BridgeBackRequestResult<BridgeType>>) -> Void)? = nil
	) -> BackRequestOperation<CoreDataFetchRequest, BridgeType>
	{
		let entity = (context.persistentStoreCoordinator?.managedObjectModel.entitiesByName[fetchRequest.entityName!])!
		return fetchObject(fromFetchRequest: fetchRequest, additionalRequestInfo: AdditionalRESTRequestInfo(flatifiedFields: flatifiedFields, inEntity: entity, keyPathPaginatorInfo: keyPathPaginatorInfo), fetchType: fetchType, onContext: context, bridge: bridge, handler: handler)
	}
	
	@discardableResult
	public func fetchObject<BridgeType, ObjectType: NSManagedObject>(
		fromFetchRequest fetchRequest: NSFetchRequest<NSFetchRequestResult>, additionalRequestInfo: AdditionalRESTRequestInfo<NSPropertyDescription>?,
		fetchType: CoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: BridgeType? = nil,
		handler: ((_ fetchedObject: ObjectType?, _ fullResponse: AsyncOperationResult<BridgeBackRequestResult<BridgeType>>) -> Void)? = nil
	) -> BackRequestOperation<CoreDataFetchRequest, BridgeType>
	{
		let bmoRequest = CoreDataFetchRequest(context: context, fetchRequest: fetchRequest, fetchType: fetchType, additionalRESTInfo: additionalRequestInfo)
		let handler = handler.flatMap { originalHandler in
			return { (_ response: AsyncOperationResult<BackRequestResult<CoreDataFetchRequest, BridgeType>>) -> Void in
				context.perform {
					let object = (try? context.fetch(fetchRequest))?.first as! ObjectType?
					#if DEBUG
						if let c = try? context.count(for: fetchRequest), c > 1 {
							if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("Got %d results where at most 1 was expected.", log: $0, type: .info, c) }}
							else                                                          {NSLog("Got %d results where at most 1 was expected.", c)}
						}
					#endif
					
					originalHandler(object, response.simpleBackRequestResult())
				}
			}
		}
		return operation(forBackRequest: bmoRequest, withBridge: bridge, autoStart: true, handler: handler)
	}
	
	@discardableResult
	public func fetchObjects<BridgeType, ObjectType: NSManagedObject>(
		fromFetchRequest fetchRequest: NSFetchRequest<NSFetchRequestResult>, withFlatifiedFields flatifiedFields: String? = nil, paginatorInfo: Any? = nil,
		fetchType: CoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: BridgeType? = nil,
		handler: ((_ fetchedObjects: [ObjectType], _ response: AsyncOperationResult<BridgeBackRequestResult<BridgeType>>) -> Void)? = nil
	) -> BackRequestOperation<CoreDataFetchRequest, BridgeType>
	{
		let entity = (context.persistentStoreCoordinator?.managedObjectModel.entitiesByName[fetchRequest.entityName!])!
		let bmoRequest = CoreDataFetchRequest(context: context, fetchRequest: fetchRequest, fetchType: fetchType, additionalRESTInfo: AdditionalRESTRequestInfo(flatifiedFields: flatifiedFields, inEntity: entity, paginatorInfo: paginatorInfo))
		let handler = handler.flatMap { originalHandler in
			return { (_ response: AsyncOperationResult<BackRequestResult<CoreDataFetchRequest, BridgeType>>) -> Void in
				context.perform {
					let objects = (try? context.fetch(fetchRequest)) as! [ObjectType]? ?? []
					
					originalHandler(objects, response.simpleBackRequestResult())
				}
			}
		}
		return operation(forBackRequest: bmoRequest, withBridge: bridge, autoStart: true, handler: handler)
	}
	
	/* ******************************
	   MARK: → Not retrieving objects
	   ****************************** */
	
	/** Creates and starts an operation for fetching and importing the object
	with the given properties from the back.
	
	The handler (if any) **won't** be called on the context. */
	@discardableResult
	public func fetchObject<BridgeType>(
		ofEntity entity: NSEntityDescription, withRemoteId remoteId: String, flatifiedFields: String? = nil, keyPathPaginatorInfo: [String: Any]? = nil, remoteIdAttributeName: String = "remoteId",
		fetchType: CoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: BridgeType? = nil,
		handler: ((_ response: AsyncOperationResult<BridgeBackRequestResult<BridgeType>>) -> Void)? = nil
	) -> BackRequestOperation<CoreDataFetchRequest, BridgeType>
	{
		let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
		fetchRequest.entity = entity
		fetchRequest.predicate = NSPredicate(format: "%K == %@", remoteIdAttributeName, remoteId)
		return operationForFetchingObjects(fromFetchRequest: fetchRequest, additionalRequestInfo: AdditionalRESTRequestInfo(flatifiedFields: flatifiedFields, inEntity: entity, keyPathPaginatorInfo: keyPathPaginatorInfo), fetchType: fetchType, onContext: context, bridge: bridge, autoStart: true, handler: handler)
	}
	
	/** Creates and starts an operation for fetching and importing the objects
	with the given properties from the back.
	
	The handler (if any) **won't** be called on the context. */
	@discardableResult
	public func fetchObjects<BridgeType>(
		fromFetchRequest fetchRequest: NSFetchRequest<NSFetchRequestResult>, withFlatifiedFields flatifiedFields: String? = nil, paginatorInfo: Any? = nil,
		fetchType: CoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: BridgeType? = nil,
		handler: ((_ response: AsyncOperationResult<BridgeBackRequestResult<BridgeType>>) -> Void)? = nil
	) -> BackRequestOperation<CoreDataFetchRequest, BridgeType>
	{
		let entity = (context.persistentStoreCoordinator?.managedObjectModel.entitiesByName[fetchRequest.entityName!])!
		return fetchObjects(fromFetchRequest: fetchRequest, additionalRequestInfo: AdditionalRESTRequestInfo(flatifiedFields: flatifiedFields, inEntity: entity, paginatorInfo: paginatorInfo), fetchType: fetchType, onContext: context, bridge: bridge, handler: handler)
	}
	
	/** Creates and starts an operation for fetching and importing the objects
	with the given properties from the back.
	
	The handler (if any) **won't** be called on the context. */
	@discardableResult
	public func fetchObjects<BridgeType>(
		fromFetchRequest fetchRequest: NSFetchRequest<NSFetchRequestResult>, additionalRequestInfo: AdditionalRESTRequestInfo<NSPropertyDescription>?,
		fetchType: CoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: BridgeType? = nil,
		handler: ((_ response: AsyncOperationResult<BridgeBackRequestResult<BridgeType>>) -> Void)? = nil
	) -> BackRequestOperation<CoreDataFetchRequest, BridgeType>
	{
		return operationForFetchingObjects(fromFetchRequest: fetchRequest, additionalRequestInfo: additionalRequestInfo, fetchType: fetchType, onContext: context, bridge: bridge, autoStart: true, handler: handler)
	}
	
	public func operationForFetchingObjects<BridgeType>(
		fromFetchRequest fetchRequest: NSFetchRequest<NSFetchRequestResult>, additionalRequestInfo: AdditionalRESTRequestInfo<NSPropertyDescription>?,
		fetchType: CoreDataFetchRequest.FetchType,
		onContext context: NSManagedObjectContext, bridge: BridgeType? = nil, autoStart: Bool,
		handler: ((_ response: AsyncOperationResult<BridgeBackRequestResult<BridgeType>>) -> Void)? = nil
	) -> BackRequestOperation<CoreDataFetchRequest, BridgeType>
	{
		let bmoRequest = CoreDataFetchRequest(context: context, fetchRequest: fetchRequest, fetchType: fetchType, additionalRESTInfo: additionalRequestInfo)
		let handler = handler.flatMap { originalHandler in
			return { (_ response: AsyncOperationResult<BackRequestResult<CoreDataFetchRequest, BridgeType>>) -> Void in
				originalHandler(response.simpleBackRequestResult())
			}
		}
		return operation(forBackRequest: bmoRequest, withBridge: bridge, autoStart: autoStart, handler: handler)
	}
	
	/* *********************
	   MARK: - Save Requests
	   ********************* */
	
	/** Saves the given objects on the back and saves (or rollbacks) the local
	context.
	
	All given objects **must** be on the given context.
	
	If `nil` is given for the objects to save on the remote, all the inserted,
	modified or deleted objects will be saved.
	
	The handler is **NOT** called on the context. */
	@discardableResult
	public func unsafeSave<BridgeType>(
		context: NSManagedObjectContext, objectsToSaveOnRemote objects: [NSManagedObject]?, additionalRequestInfo: AdditionalRESTRequestInfo<NSPropertyDescription>? = nil, rollbackInsteadOfSave: Bool = false,
		bridge: BridgeType? = nil,
		handler: ((_ response: AsyncOperationResult<BackRequestResult<CoreDataSaveRequest, BridgeType>>) -> Void)? = nil
	) -> BackRequestOperation<CoreDataSaveRequest, BridgeType>?
	{
		return unsafeOperationForSaving(context: context, objectsToSaveOnRemote: objects, additionalRequestInfo: additionalRequestInfo, saveWorkflow: rollbackInsteadOfSave ? .rollbackBeforeBackReturns : .saveBeforeBackReturns, bridge: bridge, autoStart: true, handler: handler)
	}
	
	/** Saves the given objects on the back and saves the local
	context after the back returns.
	
	All given objects **must** be on the given context.
	
	If `nil` is given for the objects to save on the remote, all the inserted,
	modified or deleted objects will be saved.
	
	The handler is **NOT** called on the context. */
	@discardableResult
	public func unsafeSaveAfterBackReturns<BridgeType>(
		context: NSManagedObjectContext, objectsToSaveOnRemote objects: [NSManagedObject]?, additionalRequestInfo: AdditionalRESTRequestInfo<NSPropertyDescription>? = nil,
		bridge: BridgeType? = nil,
		handler: ((_ response: AsyncOperationResult<BackRequestResult<CoreDataSaveRequest, BridgeType>>) -> Void)? = nil
		) -> BackRequestOperation<CoreDataSaveRequest, BridgeType>?
	{
		return unsafeOperationForSaving(context: context, objectsToSaveOnRemote: objects, additionalRequestInfo: additionalRequestInfo, saveWorkflow: .saveAfterBackReturns, bridge: bridge, autoStart: true, handler: handler)
	}
	
	public func unsafeOperationForSaving<BridgeType>(
		context: NSManagedObjectContext, objectsToSaveOnRemote objects: [NSManagedObject]?, additionalRequestInfo: AdditionalRESTRequestInfo<NSPropertyDescription>? = nil, saveWorkflow: CoreDataSaveRequest.SaveWorkflow = .saveBeforeBackReturns,
		bridge: BridgeType? = nil,
		autoStart: Bool, handler: ((_ response: AsyncOperationResult<BackRequestResult<CoreDataSaveRequest, BridgeType>>) -> Void)? = nil
	) -> BackRequestOperation<CoreDataSaveRequest, BridgeType>?
	{
		let op = operation(forBackRequest: CoreDataSaveRequest(db: context, additionalRESTInfo: additionalRequestInfo, objectsToSave: objects, saveWorkflow: saveWorkflow), withBridge: bridge, autoStart: false, handler: handler)
		if autoStart {
			do    {try op.unsafePrepareStart()}
			catch {handler?(.error(error)); return nil}
			op.start()
		}
		return op
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private static func fetchRequestForFetchingObject(ofEntity entity: NSEntityDescription, withRemoteId remoteId: String?, remoteIdAttributeName: String = "remoteId") -> NSFetchRequest<NSFetchRequestResult> {
		let fetchRequest = NSFetchRequest<NSFetchRequestResult>(); fetchRequest.entity = entity; fetchRequest.fetchLimit = 1
		if let remoteId = remoteId {fetchRequest.predicate = NSPredicate(format: "%K == %@", remoteIdAttributeName, remoteId)}
		return fetchRequest
	}
	
}