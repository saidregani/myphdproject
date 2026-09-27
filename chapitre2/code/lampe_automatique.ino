// Lampe automatique - exemple fil rouge
const int capteur = A0;   // milieu LDR / R1
const int relais  = 10;   // base de Q1 via R2
const int seuil   = 500;  // à ajuster

void setup() {
  pinMode(relais, OUTPUT);
  Serial.begin(9600);
}

void loop() {
  int lumiere = analogRead(capteur); // 0 à 1023
  Serial.println(lumiere);
  if (lumiere < seuil) {
    digitalWrite(relais, HIGH);   // obscurité : allumée
  } else {
    digitalWrite(relais, LOW);    // jour : éteinte
  }
  delay(200);
}
