import Foundation

let str = """
{\"key\":\"value\"}
"""
print(str)

let data = str.data(using: .utf8)!
do {
    let obj = try JSONSerialization.jsonObject(with: data)
    print("Parsed:", obj)
} catch {
    print("Error:", error)
}
