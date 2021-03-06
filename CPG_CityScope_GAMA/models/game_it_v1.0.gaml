/**
* Name: gamit
* Author: Arnaud, Tri, Patrick, Benoit
* Description: Describe here the model and its experiments
* Tags: Tag1, Tag2, TagN
*/

model gamit

import "../includes/data_viz/pie_charts.gaml"

global {
	string case_study <- "volpe_game_it" ;
	int nb_people <- 1000;
	file<geometry> buildings_shapefile <- file<geometry>("../includes/"+case_study+"/Buildings.shp");
	file<geometry> parks_shapefile <- file<geometry>("../includes/"+case_study+"/Park.shp");
	file<geometry> amenities_shapefile <- file_exists("../includes/"+case_study+"/amenities.shp") ? file<geometry>("../includes/"+case_study+"/amenities.shp") : nil;
	file<geometry> roads_shapefile <- file<geometry>("../includes/"+case_study+"/Roads.shp");
	file activity_file <- file("../includes/game_IT/ActivityTablePerProfile.csv");
	file criteria_file <- file("../includes/game_IT/CriteriaFile.csv");
	file dataOnProfils_file <- file("../includes/game_IT/DataOnProfiles.csv");
	file modeCharacteristics_file <- file("../includes/game_IT/ModeCharacteristics.csv");
	file dataOnMobilityMode_file <- file("../includes/game_IT/DataOnModes.csv");
	
	
	file clock_normal     const: true <- image_file("../images/clock.png");
	file clock_big_hand   const: true <- image_file("../images/big_hand.png");
	file clock_small_hand const: true <- image_file("../images/small_hand.png");
	
	float luminosity update: 1.0 - abs(12 - current_date.hour)/12;
	
	map<string,rgb> color_per_usage <- [ "Restaurant"::#2B6A89, "Night"::#1B2D36,"GP"::#244251, "Cultural"::#2A7EA6, "Shopping"::#1D223A, "HS"::#FFFC2F, "Uni"::#807F30, "O"::#545425, "R"::#222222, "Park"::#24461F];
	map<string,rgb> color_per_type <- [ "High School Student"::#FFFFB2, "College student"::#FECC5C,"Young professional"::#FD8D3C,  "Mid-career workers"::#F03B20, "Executives"::#BD0026, "Home maker"::#0B5038, "Retirees"::#8CAB13];
	
	geometry shape <- envelope(roads_shapefile);
	
	map<string,map<string,int>> activity_data;
	float step <- 1 #mn;
	date starting_date <- date([2017,9,25,0,0]);
	
	list<building> residential_buildings;
	list<building> office_buildings;
	list<string> mobility_list <- ["walking", "bike","car","bus"];
	
	map<string, float> proportion_per_type;
	map<string, float> proba_bike_per_type;
	map<string, float> proba_car_per_type;
	
	
	map<string,rgb> color_per_mobility;
	map<string,float> width_per_mobility ;
	map<string,float> speed_per_mobility;
	map<string,graph> graph_per_mobility;
	map<string,list<float>> charact_per_mobility;
	
	map<road,float> congestion_map;  
	map<string,map<string,list<float>>> weights_map <- map([]);
	
	// outputs
	map<string,int> transport_type_cumulative_usage <- map(mobility_list collect (each::0));
	map<string, int> buildings_distribution <- map(color_per_usage.keys collect (each::0));
	bool updatePollution <-false;
	
	init {
		gama.pref_display_flat_charts <- true;
		do profils_data_import;
		do modes_data_import;
		do activity_data_import;
		do criteria_file_import;
		do characteristic_file_import;
		do import_shapefiles;	
		
		do compute_graph;
		ask building {
			color <- color_per_usage[usage]; 
		}
		
		create bus_stop number: 6 {
			location <- one_of(building).location;
		}
		
		create bus {
			stops <- list(bus_stop);
			location <- first(stops).location;
			stop_passengers <- map<bus_stop, list<people>>(stops collect(each::[]));
		}		
		
		create people number: nb_people {
			type <- proportion_per_type.keys[rnd_choice(proportion_per_type.values)];
			has_car <- flip(proba_car_per_type[type]);
			has_bike <- flip(proba_bike_per_type[type]);
			living_place <- one_of(residential_buildings);
			current_place <- living_place;
			location <- any_location_in(living_place);
			color <- color_per_type[type];
			closest_bus_stop <- bus_stop with_min_of(each distance_to(self));						
			do create_trip_objectives;
		}
		
				
		/*create externalCities{
			id <-"boston";
			real_location<-{world.shape.width*1.2,world.shape.height*0.375};
			entry_location<-{3411,3906};
			location<-entry_location;
			shape<-circle(100);
	        people_distribution <-[0.2,0.1,0.1,0.2,0.1,0.2,0.1];
	        building_distribution <-[0.2,0.1,0.1,0.2,0.1,0.2,0.1];
	        create people number: nb_people/4 {
				type <- proportion_per_type.keys[rnd_choice(proportion_per_type.values)];
				has_car <- flip(proba_car_per_type[type]);
				has_bike <- flip(proba_bike_per_type[type]);
				living_place <- myself;
				current_place <- living_place;
				location <- any_location_in(living_place);
				color <- color_per_type[type];
				closest_bus_stop <- bus_stop with_min_of(each distance_to(self));						
				do create_trip_objectives;
		    }
		}
		
		create externalCities{
			id <-"harvard";
			real_location<-{-world.shape.width*0.2,world.shape.height*0.375};
			entry_location<-{3411,3906};
	        people_distribution <-[0.2,0.1,0.1,0.2,0.1,0.2,0.1];
	        building_distribution <-[0.2,0.1,0.1,0.2,0.1,0.2,0.1];
	        create people number: nb_people/4 {
				type <- proportion_per_type.keys[rnd_choice(proportion_per_type.values)];
				has_car <- flip(proba_car_per_type[type]);
				has_bike <- flip(proba_bike_per_type[type]);
				living_place <- myself;
				current_place <- living_place;
				location <- any_location_in(living_place);
				color <- color_per_type[type];
				closest_bus_stop <- bus_stop with_min_of(each distance_to(self));						
				do create_trip_objectives;
		    }
		}*/
		
		create pie{
			id <- "transport";
			labels <- transport_type_cumulative_usage.keys;
			labels_h_offset <- [diameter*10,diameter*8,diameter*5,diameter*6];
			labels_v_offset <- diameter ;
			values <- transport_type_cumulative_usage.values;
			colors <- color_per_mobility.values;
			location <-{world.shape.width*0.9,world.shape.height*0.75};
			diameter <- world.shape.width*0.10;
			inner_diameter <- diameter*0.8;
			type <- "ring";
			line_width <- diameter / 400;
			font_size <- diameter/30;
			do calculate_pies;
		}
		
		create pie{
			id <- "people";
			labels <- proportion_per_type.keys;
			labels_h_offset <- [diameter*10,diameter*10,diameter*10,diameter*10,diameter*23,diameter*13,diameter*10];
			labels_v_offset <- diameter ;
			values <- proportion_per_type.values;
			colors <- color_per_type.values;
			location <-{world.shape.width*0.9,world.shape.height*0.95};
			diameter <- world.shape.width*0.10;
			inner_diameter <- diameter*0.8;
			type <- "pie";
			line_width <- diameter / 400;
			font_size <- diameter/40;
			do calculate_pies;
		}


		
	   /*create pie{
			id <- "usage";
			labels <- buildings_distribution.keys;
			labels_h_offset <- [diameter*10,diameter*10,diameter*10,diameter*10,diameter*23,diameter*13,diameter*10,diameter*10,diameter*10,diameter*10];
			labels_v_offset <- diameter ;
			colors <- color_per_usage.values;
			location <-{world.shape.width*0.9,world.shape.height*0.55};
			diameter <- world.shape.width*0.10;
			inner_diameter <- diameter*0.8;
			type <- "pie";
			line_width <- diameter / 400;
			font_size <- diameter/40;
			do calculate_pies;
		}*/
		
		
	}
	action modes_data_import {
		matrix mode_matrix <- matrix(dataOnMobilityMode_file);
		loop i from: 0 to:  mode_matrix.rows - 1 {
			string type <- mode_matrix[0,i];
			if(type != "") {
				color_per_mobility[type] <- rgb(mode_matrix[1,i]);
				width_per_mobility[type] <- float(mode_matrix[2,i]);
				speed_per_mobility[type] <- float(mode_matrix[3,i]);
			}
		}
	}
	
	action profils_data_import {
		matrix profil_matrix <- matrix(dataOnProfils_file);
		loop i from: 0 to:  profil_matrix.rows - 1 {
			string profil_type <- profil_matrix[0,i];
			if(profil_type != "") {
				//color_per_type[profil_type] <- rgb(profil_matrix[1,i]);
				proba_car_per_type[profil_type] <- float(profil_matrix[2,i]);
				proba_bike_per_type[profil_type] <- float(profil_matrix[3,i]);
				proportion_per_type[profil_type] <- float(profil_matrix[4,i]);
			}
		}
	}
	
	action import_shapefiles {
		create road from: roads_shapefile {
			mobility_allowed << "walking";
			mobility_allowed << "bike";
			mobility_allowed << "car";
			mobility_allowed << "bus";
			capacity <- shape.perimeter / 10.0;
			congestion_map [self] <- shape.perimeter;
		}
		create building from: buildings_shapefile with: [usage::string(read ("Usage")),scale::string(read ("Scale"))] ;
		create building from: parks_shapefile{
			usage<-"Park";
		}
		
		if (amenities_shapefile != nil) {
			loop am over: amenities_shapefile {
				ask (building closest_to am) {
					usage <- "Restaurant";
					scale <- am get "Scale";
					name <- am get "name";
				} 
			}
		}
		office_buildings <- building where (each.usage = "O");
		residential_buildings <- building where (each.usage = "R");
		
		//do random_init;//Only if we don't have the information 	
	}
	
	
	
	user_command "add bus_stop" {
		create bus_stop returns: new_bus_stop {
			location <- #user_location;
		}
		// recompute bus line
		bus_stop closest_bus_stop <- (bus_stop - first(new_bus_stop)) with_min_of(each distance_to(#user_location));
		ask bus {
			int i <- (stops index_of(closest_bus_stop));
			bus_stop bb <- first(new_bus_stop);
			add bb at: i to: stops ;
		}
		
	}	
	
	action characteristic_file_import {
		matrix criteria_matrix <- matrix (modeCharacteristics_file);
		loop i from: 0 to:  criteria_matrix.rows - 1 {
			string mobility_type <- criteria_matrix[0,i];
			if(mobility_type != "") {
				list<float> vals <- [];
				loop j from: 1 to:  criteria_matrix.columns - 1 {
					vals << float(criteria_matrix[j,i]);	
				}
				charact_per_mobility[mobility_type] <- vals;
			}
		}
	}
	action criteria_file_import {
		matrix criteria_matrix <- matrix (criteria_file);
		int nbCriteria <- criteria_matrix[1,0] as int;
		int nbTO <- criteria_matrix[1,1] as int ;
		int lignCategory <- 2;
		int lignCriteria <- 3;
		
		loop i from: 5 to:  criteria_matrix.rows - 1 {
			string people_type <- criteria_matrix[0,i];
			int index <- 1;
			map<string, list<float>> m_temp <- map([]);
			if(people_type != "") {
				list<float> l <- [];
				loop times: nbTO {
					list<float> l2 <- [];
					loop times: nbCriteria {
						add float(criteria_matrix[index,i]) to: l2;
						index <- index + 1;
					}
					string cat_name <-  criteria_matrix[index-nbTO,lignCategory];
					loop cat over: cat_name split_with "|" {
						add l2 at: cat to: m_temp;
					}
				}
				add m_temp at: people_type to: weights_map;
			}
		}
	}

	 
	
	action random_init {
		ask one_of (office_buildings) {
			usage <- "Uni";
			office_buildings >> self;
		}
		ask one_of (office_buildings) {
			usage <- "Shopping";
			office_buildings >> self;
		}
		ask one_of (office_buildings) {
			usage <- "Night";
			office_buildings >> self;
		}
		ask one_of (office_buildings) {
			usage <- "Park";
			office_buildings >> self;
		}
		ask one_of (office_buildings) {
			usage <- "HS";
			office_buildings >> self;
		}
		ask one_of (office_buildings) {
			usage <- "Cultural";
			office_buildings >> self;
		}
	}
	
	action compute_graph {
		loop mobility_mode over: color_per_mobility.keys {
			graph_per_mobility[mobility_mode] <- as_edge_graph(road where (mobility_mode in each.mobility_allowed)) use_cache false;	
		}
	}
	
	action activity_data_import {
		matrix activity_matrix <- matrix (activity_file);
		loop i from: 1 to:  activity_matrix.rows - 1 {
			string people_type <- activity_matrix[0,i];
			map<string, int> activities;
			string current_activity <- "";
			loop j from: 1 to:  activity_matrix.columns - 1 {
				string act <- activity_matrix[j,i];
				if (act != current_activity) {
					activities[act] <-j;
					 current_activity <- act;
				}
			}
			activity_data[people_type] <- activities;
		}
	}
	
	
	reflex update_road_weights {
		ask road {
			do update_speed_coeff;	
			congestion_map [self] <- speed_coeff;
		}
	}
	
	reflex update_buildings_distribution{
		buildings_distribution <- map(color_per_usage.keys collect (each::0));
		ask building{
			buildings_distribution[usage] <- buildings_distribution[usage]+1;
		}
	}
	
	reflex update_charts{
		ask pie {
			switch(self.id)
			{
				match "transport" {do update_values(transport_type_cumulative_usage.values);}
				match "people" {do update_values(proportion_per_type.values);}
				match "usage" {do update_values(buildings_distribution.values);}
			}
			do calculate_pies;
		}

	}
	
}

species trip_objective{
	building place; 
	int starting_hour;
	int starting_minute;
}

species bus_stop {
	list<people> waiting_people;
	
	aspect c {
		draw circle(30) color: empty(waiting_people)?#black:#blue border: #black depth:1;
	}
}

species bus skills: [moving] {
	list<bus_stop> stops; 
	map<bus_stop,list<people>> stop_passengers ;
	bus_stop my_target;
	
	reflex new_target when: my_target = nil{
		bus_stop firstStop <- first(stops);
		remove firstStop from: stops;
		add firstStop to: stops; 
		my_target <- firstStop;
	}
	
	reflex r {
		do goto target: my_target.location on: graph_per_mobility["car"] speed:speed_per_mobility["bus"];
		if(location = my_target.location) {
			////////      release some people
			ask stop_passengers[my_target] {
				location <- myself.my_target.location;
				bus_status <- 2;
			}
			stop_passengers[my_target] <- [];
			
			/////////     get some people
			loop p over: my_target.waiting_people {
				bus_stop b <- bus_stop with_min_of(each distance_to(p.my_current_objective.place.location));
				add p to: stop_passengers[b] ;
			}
			my_target.waiting_people <- [];						
			my_target <- nil;			
		}
		
	}
	
	aspect bu {
		draw rectangle(40,20) color: empty(stop_passengers.values accumulate(each))?#yellow:#red border: #black;
	}
	
}

grid plot_pollution height: 20 width: 20 {
	int pollution_level <- 0 ;
	rgb color <- hsb(pollution_level,1.0,1.0) update: hsb(pollution_level,1.0,1.0);
	
	reflex raz when: every(1#day) {
		pollution_level <- 0;
	}
}

species people skills: [moving]{
	string type;
	rgb color ;
	int size<-15;
	building living_place;
	list<trip_objective> objectives;
	trip_objective my_current_objective;
	building current_place;
	string mobility_mode;
	list<string> possible_mobility_modes;
	bool has_car ;
	bool has_bike;

	//
	bus_stop closest_bus_stop;	
	int bus_status <- 0;
	
	action create_trip_objectives {
		map<string,int> activities <- activity_data[type];
		//if (activities = nil ) or (empty(activities)) {write "my type: " + type;}
		loop act over: activities.keys {
			if (act != "") {
				list<string> parse_act <- act split_with "|";
				string act_real <- one_of(parse_act);
				list<building> possible_bds;
				if (length(act_real) = 2) and (first(act_real) = "R") {
					possible_bds <- building where ((each.usage = "R") and (each.scale = last(act_real)));
				} 
				else if (length(act_real) = 2) and (first(act_real) = "O") {
					possible_bds <- building where ((each.usage = "O") and (each.scale = last(act_real)));
				} 
				else {
					possible_bds <- building where (each.usage = act_real);
				}
				building act_build <- one_of(possible_bds);
				if (act_build= nil) {write "problem with act_real: " + act_real;}
				do create_activity(act_real,act_build,activities[act]);
			}
		}
	}
	
	action create_activity(string act_name, building act_place, int act_time) {
		create trip_objective {
			name <- act_name;
			place <- act_place;
			starting_hour <- act_time;
			starting_minute <- rnd(60);
			myself.objectives << self;
		}
	} 
	
	action choose_mobility_mode {
		list<list> cands <- mobility_mode_eval();
		map<string,list<float>> crits <-  weights_map[type];
		list<float> vals ;
		loop obj over:crits.keys {
			if (obj = my_current_objective.name) or
			 ((my_current_objective.name in ["RS", "RM", "RL"]) and (obj = "R"))or
			 ((my_current_objective.name in ["OS", "OM", "OL"]) and (obj = "O")){
				vals <- crits[obj];
				break;
			} 
		}
		list<map> criteria_WM;
		loop i from: 0 to: length(vals) - 1 {
			criteria_WM << ["name"::"crit"+i, "weight" :: vals[i]];
		}
		int choice <- weighted_means_DM(cands, criteria_WM);
		if (choice >= 0) {
			mobility_mode <- possible_mobility_modes [choice];
		} else {
			mobility_mode <- one_of(possible_mobility_modes);
		}
		transport_type_cumulative_usage[mobility_mode] <- transport_type_cumulative_usage[mobility_mode] + 1;
		speed <- speed_per_mobility[mobility_mode];
	}
	
	list<list> mobility_mode_eval {
		list<list> candidates;
		loop mode over: possible_mobility_modes {
			list<float> characteristic <- charact_per_mobility[mode];
			list<float> cand;
			float distance <-  0.0;
			using topology(graph_per_mobility[mode]){
				distance <-  distance_to (location,my_current_objective.place.location);
			}
			cand << characteristic[0] + characteristic[1]*distance;
			cand << characteristic[2] #mn +  distance / speed_per_mobility[mode];
			cand << characteristic[4];
			cand << characteristic[5];
			add cand to: candidates;
		}
		
		//normalisation
		list<float> max_values;
		loop i from: 0 to: length(candidates[0]) - 1 {
			max_values << max(candidates collect abs(float(each[i])));
		}
		loop cand over: candidates {
			loop i from: 0 to: length(cand) - 1 {
				if ( max_values[i] != 0.0) {cand[i] <- float(cand[i]) / max_values[i];}
				
			}
		}
		return candidates;
	}
	
	action updatePollutionMap{
		ask plot_pollution overlapping(current_path.shape) {
			pollution_level <- pollution_level + 1;
		}
	}	
	
	reflex choose_objective when: my_current_objective = nil {
	    //location <- any_location_in(current_place);
		do wander speed:0.01;
		my_current_objective <- objectives first_with ((each.starting_hour = current_date.hour) and (current_date.minute >= each.starting_minute) and (current_place != each.place) );
		if (my_current_objective != nil) {
			current_place <- nil;
			possible_mobility_modes <- ["walking"];
			if (has_car) {possible_mobility_modes << "car";}
			if (has_bike) {possible_mobility_modes << "bike";}
			possible_mobility_modes << "bus";				
			do choose_mobility_mode;
		}
	}
	reflex move when: (my_current_objective != nil) and (mobility_mode != "bus") {
		if ((current_edge != nil) and (mobility_mode in ["car"])) {road(current_edge).current_concentration <- max([0,road(current_edge).current_concentration - 1]); }
		if (mobility_mode in ["car"]) {
			do goto target: my_current_objective.place.location on: graph_per_mobility[mobility_mode] move_weights: congestion_map ;
		}else {
			do goto target: my_current_objective.place.location on: graph_per_mobility[mobility_mode]  ;
		}
		
		if (location = my_current_objective.place.location) {
			if(mobility_mode = "car" and updatePollution = true) {do updatePollutionMap;}						
			current_place <- my_current_objective.place;
			location <- any_location_in(current_place);
			my_current_objective <- nil;	
			mobility_mode <- nil;
		} else {
			if ((current_edge != nil) and (mobility_mode in ["car"])) {road(current_edge).current_concentration <- road(current_edge).current_concentration + 1; }
		}
	}
	
	reflex move_bus when: (my_current_objective != nil) and (mobility_mode = "bus") {

		if (bus_status = 0){
			do goto target: closest_bus_stop.location on: graph_per_mobility["walking"];
			
			if(location = closest_bus_stop.location) {
				add self to: closest_bus_stop.waiting_people;
				bus_status <- 1;
			}
		} else if (bus_status = 2){
			do goto target: my_current_objective.place.location on: graph_per_mobility["walking"];		
		
			if (location = my_current_objective.place.location) {
				current_place <- my_current_objective.place;
				closest_bus_stop <- bus_stop with_min_of(each distance_to(self));						
				location <- any_location_in(current_place);
				my_current_objective <- nil;	
				mobility_mode <- nil;
				bus_status <- 0;
			}
		}
	}	
	
	aspect default {
		if (mobility_mode = nil) {
			draw circle(size) at: location + {0,0,(current_place != nil ?current_place.height : 0.0) + 4}  color: color ;
		} else {
			if (mobility_mode = "walking") {
				draw circle(size) color: color  ;
			}else if (mobility_mode = "bike") {
				draw triangle(size) rotate: heading +90  color: color depth: 8 ;
			} else if (mobility_mode = "car") {
				draw square(size*2)  color: color ;
			}
		}
	}
	
	aspect timelapse {
      draw circle(size/2) at: {location.x,location.y,cycle} + {0,0,(current_place != nil ?current_place.height : 0.0) + 4}  color: color ;
	}
}

species road  {
	list<string> mobility_allowed;
	float capacity;
	float max_speed <- 30 #km/#h;
	float current_concentration;
	float speed_coeff <- 1.0;
	
	action update_speed_coeff {
		speed_coeff <- shape.perimeter / max([0.01,exp(-current_concentration/capacity)]);
	}
	
	aspect default {		
		draw shape color:rgb(125,125,125);
	}
	
	aspect mobility {
		string max_mobility <- mobility_allowed with_max_of (width_per_mobility[each]);
		
		draw shape width: width_per_mobility[max_mobility] color:color_per_mobility[max_mobility] ;
	}
	
	user_command to_pedestrian_road {
		mobility_allowed <- ["walking", "bike"];
		ask world {do compute_graph;}
	}
}

species building {
	string usage;
	string scale;
	rgb color <- #grey;
	float height <- 50.0 + rnd(50);
	aspect default {
		draw shape color: color ;
	}
	aspect depth {
		draw shape color: color  depth: height;
	}
}


species externalCities parent:building{
	string id;
	point real_location;
	point entry_location;
	list<float> people_distribution;
	list<float> building_distribution;
	list<building> external_buildings;
	
	aspect base{
		draw circle(100) color:#yellow at:real_location;
		draw circle(100) color:#red at:entry_location;
	}
}

experiment gameit type: gui {
	output {
		display map type: opengl draw_env: false background: #black refresh_every:10{//rgb(255 *luminosity,255*luminosity, 255*luminosity ){
			species pie;
			species building aspect:depth refresh: false;
			species road ;
			//species bus_stop aspect: c;
			//species bus aspect: bu; 			
			species people;
			species externalCities aspect:base;

			

			
			graphics "time" {
				point loc <- {-1350,2000};
				draw string(current_date.hour) + "h" + string(current_date.minute) +"m" color: # white font: font("Helvetica", 25, #italic) at: {world.shape.width*0.9,world.shape.height*0.55};
				/*draw clock_normal size: 400 at:loc ;
				draw clock_big_hand rotate: current_date.minute*(360/60)  + 90  size: {400,400/14} at:loc + {0,0,0.1}; 
				draw clock_small_hand rotate: current_date.hour*(360/12)  + 90  size: {240,240/10} at:loc + {0,0,0.1};		 */
			}
			
			overlay position: { 5, 5 } size: { 240 #px, 680 #px } background: # black transparency: 1.0 border: #black 
            {
            	//for each possible type, we draw a square with the corresponding color and we write the name of the type
                rgb text_color<-#darkgray;
                float y <- 30#px;
  				draw "Building Usage" at: { 40#px, y } color: text_color font: font("SansSerif", 20, #bold);
                y <- y + 30 #px;
                loop type over: color_per_usage.keys
                {
                    draw square(10#px) at: { 20#px, y } color: color_per_usage[type] border: #white;
                    draw type at: { 40#px, y + 4#px } color: text_color font: font("SansSerif", 18, #bold);
                    y <- y + 25#px;
                }
                 y <- y + 30 #px;
                draw "People Type" at: { 40#px, y } color: text_color font: font("SansSerif", 20, #bold);
                y <- y + 30 #px;
                loop type over: color_per_type.keys
                {
                    draw square(10#px) at: { 20#px, y } color: color_per_type[type] border: #white;
                    draw type at: { 40#px, y + 4#px } color: text_color font: font("SansSerif", 18, #bold);
                    y <- y + 25#px;
                }
				 y <- y + 30 #px;
                draw "Mobility Mode" at: { 40#px, y } color: text_color font: font("SansSerif", 20, #bold);
                y <- y + 30 #px;
                draw circle(10#px) at: { 20#px, y } color:#white border: #black;
                draw "Walking" at: { 40#px, y + 4#px } color: text_color font: font("SansSerif", 18, #bold);
                 y <- y + 25#px;
                draw triangle(15#px) at: { 20#px, y } color:text_color  border: #black;
                draw "Bike" at: { 40#px, y + 4#px } color: text_color font: font("SansSerif", 18, #bold);
                y <- y + 25#px;
                 draw square(20#px) at: { 20#px, y } color:text_color border: #black;
                draw "Car" at: { 40#px, y + 4#px } color: text_color font: font("SansSerif", 18, #bold);       
            }
		} 

		/*display timelapse type: opengl background: #black refresh_every:10{
		  species people aspect:timelapse trace: 2500;		
		}*/		
		
	}
}
