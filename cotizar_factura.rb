require 'net/http'
require 'json'
require 'date'
require 'yaml'


def cargar_configuracion
  YAML.load_file('config.yaml')
end

def cargar_datos_factura
  YAML.load_file('factura.yaml')
end


def cotizar_factura(rut_emisor, rut_receptor, monto, folio, fecha_vencimiento, api_key)
  endpoint = 'https://chita.cl/api/v1/pricing/simple_quote'
  uri = URI("#{endpoint}?client_dni=#{rut_emisor}&debtor_dni=#{rut_receptor}&document_amount=#{monto}&folio=#{folio}&expiration_date=#{fecha_vencimiento}")
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  request = Net::HTTP::Get.new(uri)
  request['X-Api-Key'] = api_key

  response = http.request(request)

  if response.code == '200'
    return JSON.parse(response.body)
  else
    puts "Error al cotizar la factura."
    puts "Código de respuesta: #{response.code}"
    return nil
  end
end

def calcular_costos(cotizacion, monto, porcentaje_anticipo, dias_plazo)
  tasa_negocio = cotizacion['document_rate']
  comision = cotizacion['commission']
  advance_percent = cotizacion['advance_percent']

  costo_financiamiento = (monto * porcentaje_anticipo) * (tasa_negocio / 100 / 30 * dias_plazo)
  giro_a_recibir = (monto * porcentaje_anticipo) - (costo_financiamiento + comision)
  excedentes = monto - (monto * porcentaje_anticipo)

  return costo_financiamiento, giro_a_recibir, excedentes
end

def imprimir_resultados(costo_financiamiento, giro_a_recibir, excedentes)
  puts "Costo de financiamiento: $#{costo_financiamiento.to_i}"
  puts "Giro a recibir: $#{giro_a_recibir.to_i}"
  puts "Excedentes: $#{excedentes.to_i}"
end

# Cargar la api_key  y datos de la factura desde archivos
configuracion = cargar_configuracion
datos_factura = cargar_datos_factura


# Calcular días de plazo
hoy = Time.now.to_date
fecha_vencimiento_parsed = Date.parse(datos_factura['fecha_vencimiento'])
dias_plazo = (fecha_vencimiento_parsed - hoy).to_i + 1

# Obtener cotización
cotizacion = cotizar_factura(
  datos_factura['rut_emisor'],
  datos_factura['rut_receptor'],
  datos_factura['monto_factura'],
  datos_factura['folio'],
  datos_factura['fecha_vencimiento'],
  configuracion['api_key']
)

if cotizacion
  # Calcular costos
  costo_financiamiento, giro_a_recibir, excedentes = calcular_costos(
    cotizacion,
    datos_factura['monto_factura'],
    cotizacion['advance_percent'] / 100,
    dias_plazo
  )

  # Mostrar resultados sin decimales
  imprimir_resultados(costo_financiamiento, giro_a_recibir, excedentes)
end

