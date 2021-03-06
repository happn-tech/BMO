/*
Copyright 2019 happn

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. */

import Foundation



struct RESTMapping<DbEntityDescription : DbRESTEntityDescription & Hashable, DbPropertyDescription : Hashable> {
	
	let entitiesMapping: [DbEntityDescription: RESTEntityMapping<DbPropertyDescription>]
	
	let queryParamParser: ParameterizedStringSetParser
	
	let forcedParametersOnFetch: [String: Any]
	let forcedValuesOnSave: [String: Any]
	
	func entityMapping(forEntity entity: DbEntityDescription) -> RESTEntityMapping<DbPropertyDescription>? {
		if let m = entitiesMapping[entity] {return m}
		guard let superentity = entity.superentity else {return nil}
		return entityMapping(forEntity: superentity as! DbEntityDescription /* See comment about SubSuperEntityType in DbRESTEntityDescription for explanation of the "as!" */)
	}
	
	/* We do not differentiate (mainly because we don't need it yet) between an
	 * entity not found in the mapping, an entity who does not have a uniquing
	 * type or an entity who have a `.none` uniquing type. */
	func entityUniquingType(forEntity entity: DbEntityDescription) -> RESTEntityUniquingType<DbPropertyDescription> {
		if let u = entitiesMapping[entity]?.uniquingType {return u}
		guard let superentity = entity.superentity else {return .none}
		return entityUniquingType(forEntity: superentity as! DbEntityDescription /* See comment about SubSuperEntityType in DbRESTEntityDescription for explanation of the "as!" */)
	}
	
	/** Will try and find the property mapping for the given property, starting
	from the given expected entity, then going up (superentities), then if still
	not found, going down (sub-entities). Will never go to an unrelated entity.
	
	If the expected entity is not given, all entities will be tested. */
	func propertyMapping(forProperty property: DbPropertyDescription, expectedEntity entity: DbEntityDescription?) -> RESTPropertyMapping? {
		guard let entity = entity else {return propertyMapping(forProperty: property)}
		return _propertyMapping(forProperty: property, expectedEntity: entity, canGoUp: true, canGoDown: true)
	}
	
	private func propertyMapping(forProperty property: DbPropertyDescription) -> RESTPropertyMapping? {
		for (entity, _) in entitiesMapping {
			if let r = propertyMapping(forProperty: property, expectedEntity: entity) {
				return r
			}
		}
		return nil
	}
	
	private func _propertyMapping(forProperty property: DbPropertyDescription, expectedEntity entity: DbEntityDescription, canGoUp: Bool, canGoDown: Bool) -> RESTPropertyMapping? {
		if let m = entitiesMapping[entity]?.propertiesMapping[property] {
			return m
		}
		
		/* Mapping not found, first let's go up if allowed. */
		if canGoUp, let superentity = entity.superentity {
			if let m = _propertyMapping(forProperty: property, expectedEntity: superentity as! DbEntityDescription, canGoUp: true, canGoDown: false) {
				return m
			}
		}
		/* Mapping still not found, let's go down if allowed. */
		if canGoDown {
			for subentity in entity.subentities {
				if let m = _propertyMapping(forProperty: property, expectedEntity: subentity as! DbEntityDescription, canGoUp: false, canGoDown: true) {
					return m
				}
			}
		}
		return nil
	}
	
}
