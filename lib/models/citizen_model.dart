class Citizen {
  final int? id;
  final String name;
  final String contactNumber;
  final String address;
  final String username;
  final String password;

  Citizen({
    this.id,
    required this.name,
    required this.contactNumber,
    required this.address,
    required this.username,
    required this.password,
  });

  // Convert a Citizen into a Map. The keys must correspond to the
  // names of the columns in the database.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'contact_number': contactNumber,
      'address': address,
      'username': username,
      'password': password,
    };
  }

  // Extract a Citizen object from a Map.
  factory Citizen.fromMap(Map<String, dynamic> map) {
    return Citizen(
      id: map['id'] as int?,
      name: map['name'] as String,
      contactNumber: map['contact_number'] as String,
      address: map['address'] as String,
      username: map['username'] as String,
      password: map['password'] as String,
    );
  }
}
