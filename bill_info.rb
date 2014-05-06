# coding: utf-8
require 'billit_representers/models/bill'
require './scrapable_classes'
require 'json'

class BillInfo < StorageableInfo

	def initialize()
		super()
		@model = 'bills'
		@id = ''
		@last_update = HTTParty.get('http://billit.ciudadanointeligente.org/bills/last_update').body
		# @last_update = "30/12/2013"
		@update_location = 'http://www.senado.cl/wspublico/tramitacion.php?fecha='
		# 
    @location = 'http://old.congreso.gob.gt/Legislacion/ver_iniciativa.asp?id='
		@bills_location = 'bills'
		@format = 'application/json'
	end

	def doc_locations
		bulletins = 5043.downto(4214) #until 2009
		bulletins.map {|b| @location + b.to_s}
	end

	def save bill
		result_code = HTTParty.get([@API_url, @model, @id].join("/"), headers: {"Accept"=>"*/*"}).code
		if result_code == 200
			puts "-------- 200 ---------"
			put bill
		else
			puts "-------- 404 ---------"
			post bill
		end
	end

	def put bill
    bill.put([@API_url, @model, bill.uid].join("/"), @format)
  end

  def post bill
    bill.post([@API_url, @model].join("/"), @format)
	end

	def format info
		bill = Billit::Bill.new

		#authors = info[:authors].map{|x| x.values}.flatten if info[:authors]
		#subject_areas = info[:subject_areas].map{|x| x.values}.flatten if info[:subject_areas]
		#merged_bills = info[:merged_bills].split('/') if info[:merged_bills]

		bill.uid = info[:uid]
		bill.title = info[:title]
    bill.creation_date = info[:creation_date]
		bill.bill_draft_link = info[:bill_draft_link]
		@id = info[:uid]
		bill
	end

  def get_info doc
		info = Hash.new
		html = Nokogiri::HTML(doc)
    base_xpath = '//html/body/table/tr/td/table/tr[2]/td/table/tr/td[2]/div[3]/table'
		info[:uid] = html.xpath(base_xpath+'//tr/td/font[1]/text()').text().to_s.gsub(/\s+/, "")[1,10] if html.xpath(base_xpath+'//tr/td/font[1]/text()')
		info[:title] = html.xpath(base_xpath+'//tr/td/font[5]/text()').text().to_s if html.xpath(base_xpath+'//tr/td/font[5]/text()')
    creation_date = html.xpath(base_xpath+'//tr/td/font[2]/text()').text().gsub(/\s+/, "")
    info[:creation_date] = Date.strptime(creation_date.to_s, '%d/%m/%Y') if html.xpath(base_xpath+'//tr/td/font[2]/text()')
		info[:bill_draft_link] = html.xpath(base_xpath+'//tr/td/a/@href').text() if html.xpath(base_xpath+'//tr/td/a/@href').text()
		info
  end

  def get_hash_field_data nokogiri_xml, field
  	field = field.to_sym
  	field_vals = []
  	path = nokogiri_xml.xpath(hash_fields[field][:xpath])
  	path.each do |field_info|
  		field_val = {}
  		hash_fields[field][:sub_fields].each do |sub_field|
  			name = sub_field[:name]
  			css = sub_field[:css]
  			field_val[name] = field_info.at_css(css).text if field_info.at_css(css)
  		end
  		field_vals.push(field_val)
  	end if path
  	field_vals
  end

  def get_model_field_data nokogiri_xml, field
    "getting model " + field.to_s
  	field_class = ("Billit" + field.to_s.classify).constantize
  	# field_class = field.to_s.classify.constantize
  	field_instances = []
  	path = nokogiri_xml.xpath(model_fields[field][:xpath])
  	path.each do |field_info|
  		field_instance = field_class.new
  		model_fields[field][:sub_fields].each do |sub_field|
  			name = sub_field[:name]
  			css = sub_field[:css]
  			field_instance.send name+'=', field_info.at_css(css).text if field_info.at_css(css)
  			# field_instance[name] = field_info.at_css(css).text if field_info.at_css(css)
  		end
  		field_instances.push(field_instance)
  		# field_class.send field+'=', field_val #ta super malo
  	end if path
  	field_instances
  end

  # Used for documents embedded within a bill,
  # posted/put as hashes instead of having their own model and representer
  def model_fields
  	{
  		paperworks: {
  			xpath: '//tramitacion/tramite',
  			sub_fields: [
  				{
    				name: 'session',
    				css: 'SESION'
    			},
    			{
    				name: 'date',
    				css: 'FECHA'
    			},
    			{
    				name: 'description',
    				css: 'DESCRIPCIONTRAMITE'
    			},
    			{
    				name: 'stage',
    				css: 'ETAPDESCRIPCION'
    			},
    			{
    				name: 'chamber',
    				css: 'CAMARATRAMITE'
    			}
  		 	]
  		},
  		priorities: {
  			xpath: '//urgencias/urgencia',
  			sub_fields: [
    			{
    				name: 'type',
    				css: 'TIPO'
    			},
    			{
    				name: 'entry_date',
    				css: 'FECHAINGRESO'
    			},
    			{
    				name: 'entry_message',
    				css: 'MENSAJEINGRESO'
    			},
    			{
    				name: 'entry_chamber',
    				css: 'CAMARAINGRESO'
    			},
    			{
    				name: 'withdrawal_date',
    				css: 'FECHARETIRO'
    			},
    			{
    				name: 'withdrawal_message',
    				css: 'MENSAJERETIRO'
    			},
    			{
    				name: 'withdrawal_chamber',
    				css: 'CAMARARETIRO'
    			}
    		]
  		},
  		reports: {
  			xpath: '//informes/informe',
  			sub_fields: [
    			{
    				name: 'date',
    				css: 'FECHAINFORME'
    			},
    			{
    				name: 'step',
    				css: 'TRAMITE'
    			},
    			{
    				name: 'stage',
    				css: 'ETAPA'
    			},
    			{
    				name: 'link',
    				css: 'LINK_INFORME'
    			}
    		]
  		},
  		documents: {
  			xpath: '//oficios/oficio',
  			sub_fields: [
    			{
    				name: 'number',
    				css: 'NUMERO'
    			},
    			{
    				name: 'date',
    				css: 'FECHA'
    			},
    			{
    				name: 'step',
    				css: 'TRAMITE'
    			},
    			{
    				name: 'stage',
    				css: 'ETAPA'
    			},
    			{
    				name: 'type',
    				css: 'TIPO'
    			},
    			{
    				name: 'chamber',
    				css: 'CAMARA'
    			},
    			{
    				name: 'link',
    				css: 'LINK_OFICIO'
    			}
    		]
  		},
  		directives: {
  			xpath: '//indicaciones/indicacion',
  			sub_fields: [
    			{
    				name: 'date',
    				css: 'FECHA'
    			},
    			{
    				name: 'step',
    				css: 'TRAMITE'
    			},
    			{
    				name: 'stage',
    				css: 'ETAPA'
    			},
    			{
    				name: 'link',
    				css: 'LINK_INDICACION'
    			}
    		]
  		},
  		remarks: {
  			xpath: '//observaciones/observacion',
  			sub_fields: [
    			{
    				name: 'date',
    				css: 'FECHA'
    			},
    			{
    				name: 'step',
    				css: 'TRAMITE'
    			},
    			{
    				name: 'stage',
    				css: 'ETAPA'
    			}
    		]
  		},
  		revisions: {
  			xpath: '//comparados/comparado',
  			sub_fields: [
  				{
    				name: 'description',
    				css: 'COMPARADO'
    			},
    			{
    				name: 'link',
    				css: 'LINK_COMPARADO'
    			}
    		]
  		}
  	}
  end

  # Used for documents embedded within a bill,
  # stored as hashes instead of having their own model and representer
  def hash_fields
  	{
  		authors: {
  			xpath: '//autores/autor',
  			sub_fields: [
  				{
    				name: 'author',
    				css: 'PARLAMENTARIO'
    			}
    		]
  		},
  		subject_areas: {
  			xpath: '//materias/materia',
  			sub_fields: [
    			{
    				name: 'subject_area',
    				css: 'DESCRIPCION'
    			}
    		]
  		}
  	}
  end
end
