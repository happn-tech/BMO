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



public class RESTUUIDTransformer : ValueTransformer {
	
	public override class func allowsReverseTransformation() -> Bool {
		return true
	}
	
	public override class func transformedValueClass() -> AnyClass {
		return NSUUID.self
	}
	
	public override func transformedValue(_ value: Any?) -> Any? {
		if let uuid = value as? UUID {return uuid}
		return (value as? String).flatMap{ UUID(uuidString: $0) }
	}
	
	public override func reverseTransformedValue(_ value: Any?) -> Any? {
		guard let uuid = value as? UUID else {return nil}
		return uuid.uuidString
	}
	
}
