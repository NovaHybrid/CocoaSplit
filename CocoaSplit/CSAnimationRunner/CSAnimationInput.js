function CSAnimationInput(cs_input) {
    
 
    this.input = cs_input;
    this.layer = cs_input.layer;
    this.animationLayer = cs_input.animationLayer();
    
    this.position = function() { return this.animationLayer.frame.origin; }
    this.width = function() { return this.animationLayer.bounds.width; }
    this.height = function() { return this.animationLayer.bounds.height; }
    this.minY = function() { return NSMinY(this.animationLayer.frame); }
    this.maxY = function() { return NSMaxY(this.animationLayer.frame); }
    this.minX = function() { return NSMinX(this.animationLayer.frame); }
    this.maxX = function() { return NSMaxX(this.animationLayer.frame); }
    this.midY = function() { return NSMidY(this.animationLayer.frame); }
    this.midX = function() { return NSMidX(this.animationLayer.frame); }


    
    this.make_animation_values = function(initial_value, anim_value, valueMaker) {
        
        var ret_val;
        
        if (isArray(anim_value))
        {
            var val_arr = [];
            if (initial_value !== undefined)
            {
                val_arr.push(initial_value)
            }
            var vLen, i;
            for(vLen = anim_value.length, i=0; i<vLen; i++)
            {
                var aVal = anim_value[i];
                var nVal = valueMaker(aVal);
                val_arr.push(nVal);
            }
            ret_val = val_arr;
        } else {
            ret_val = valueMaker(anim_value);
        }
        
        return ret_val;
    }
    
    
    this.basic_animation = function(forKey, withDuration) {
        var cab = CABasicAnimation.animationWithKeyPath(forKey);
        if (withDuration === undefined)
        {
            cab.duration = CSAnimationBlock.currentFrame().duration;
        } else {
            cab.duration = withDuration;
        }
        return cab;
    }
    
    this.add_animation = function(animation, target, keyPath) {
        animation.cs_input = this;
        CSAnimationBlock.currentFrame().add_animation(animation, target, keyPath);
        return animation;
    }
    
    this.keyframe_animation = function(forKey, withDuration) {
        var kanim = CAKeyframeAnimation.animationWithKeyPath(forKey);
        if (withDuration !== undefined)
        {
            kanim.duration = withDuration;
        } else {
            kanim.duration = CSAnimationBlock.currentFrame().duration;
        }
        kanim.calculationMode = "paced";
        kanim.rotationMode = "autoReverse";
        return kanim;
    }
    
    
    this.simple_animation = function(forKey, toValue, withDuration, kwargs) {
        var real_end_value = toValue;
        
        if (kwargs === undefined)
        {
            kwargs = {};
        }
        
        var default_kwargs = CSAnimationBlock.currentFrame().animation_info['__cs_default_kwargs'];
        var merged_kwargs = Object.assign({}, default_kwargs, kwargs);
        
        if (merged_kwargs === undefined)
        {
            merged_kwargs = {};
        }
        var for_layer = this.layer;
        
        var banim;
        if (isArray(toValue))
        {
            banim = this.keyframe_animation(forKey, withDuration);
            real_end_value = toValue[-1];
            banim.values = toValue;
        } else {
            banim = this.basic_animation(forKey, withDuration);
            if (merged_kwargs["use_fromVal"])
            {
                banim.fromValue = merged_kwargs["use_fromVal"];
            }
            banim.toValue = toValue;
        }
        
        
        if (merged_kwargs["source_only"])
        {
            for_layer = this.layer.sourceLayer;
        }
        
        if (merged_kwargs["use_layer"])
        {
            for_layer = merged_kwargs["use_layer"]
        }
        
        var csanim = new CSAnimation(for_layer, forKey, banim, merged_kwargs);
        if (!merged_kwargs["autoreverse"])
        {
            this.animationLayer.setValueForKeyPath(real_end_value, forKey);
        }
        if (merged_kwargs["extra_keypath"])
        {
            this.animationLayer.setValueForKeyPath(real_end_value, merged_kwargs["extra_keypath"]);
        }
        
        csanim.toValue = real_end_value;
        return this.add_animation(csanim, for_layer, forKey);
        
    }
    /**
     * Wait for all in-progress animations on this input to complete before adding any more.
     * This ONLY changes the timing for the input this wait is applied to. Example:
     * input1.moveTo(0,0,2.5)
     * input2.moveTo(100,100.5.5)
     * input1.waitAnimation()
     * input2.rotate(360, 5.5)
     * input1.moveCenter(3.5)
     *
     * input1 will start to move towards the bottom left corner and simultaneously input2 will begin its rotation AND begin moving to 100,100.
     * After input1 finishes moving to the corner it will then start moving towards the center.
     * Notice that the timing of input2's animations are not modified by the waitAnimation() on input1.
     
     * Like the global waitAnimation() you can specify a keyword argument of 'label' to wait on a specific animation.
     */
    this.waitAnimation = function(duration, kwargs) {
        return CSAnimationBlock.currentFrame().waitAnimation(duration, this, kwargs);
    }
    
    /**
     * Wait duration seconds before starting any new animations on this input. As described previously in waitAnimation() this
     * only modifies the timing of animations on THIS input.
     */
    this.wait = function(duration) {
        return CSAnimationBlock.currentFrame().wait(duration, this);
    }

    this.adjust_coordinates = function(x, y) {
    
        var m_width = this.animationLayer.frame.width;
        var m_height = this.animationLayer.frame.height;
        var c_x = this.animationLayer.frame.x;
        var c_y = this.animationLayer.frame.y;
        return {x:x-c_x, y:y-c_y};
    }

    
    this.real_coordinate_from_fract = function(x,y) {
        var ret_x = x;
        var ret_y = y;
        if (x > 0.0 && x <= 1.0)
        {
            var slayer = this.layer.superlayer();
            ret_x = slayer.bounds.x + (slayer.bounds.width * x);
        }
        
        if (y > 0.0 && y <= 1.0)
        {
            var slayer = this.layer.superlayer();
            ret_y = slayer.bounds.y + (slayer.bounds.height *y);
        }
        return {x: ret_x, y: ret_y};
    }
        
    
  
    
    /**
     * Move the input's Y coordinate. This change is permanent/saved. If you want non-saved move use the translate* animations
     * @param {number} move_y - the amount to move the input's Y coordinate
     */
    this.moveY = function(move_y, duration, kwargs) {
        kwargs = kwargs || {};
        var cpos = this.animationLayer.position;
        self = this;
        var vmk = function(val) {
            var new_coord = self.real_coordinate_from_fract(0,val);
            cpos.y = cpos.y + new_coord.y;
            return cpos.y;
        }
        
        var anim_vals = this.make_animation_values(cpos.y, move_y, vmk);
        return this.simple_animation('position.y', anim_vals, duration, kwargs);
    }
        
    
 
    /**
     * Move the input's X coordinate. This change is permanent/saved. If you want non-saved move use the translate* animations
     * @param {number} move_=x - the amount to move the input's X coordinate
     */
    this.moveX = function(move_x, duration, kwargs) {
        kwargs = kwargs || {};
        var cpos = this.animationLayer.position;
        self = this;
        var vmk = function(val) {
            var new_coord = self.real_coordinate_from_fract(val,0);
            cpos.x = cpos.x + new_coord.x;
            return cpos.x;
        }
        
        var anim_vals = this.make_animation_values(cpos.x, move_x, vmk);
        return this.simple_animation('position.x', anim_vals, duration, kwargs);
    }
        
    
    /**
     * Apply a uniform scale transform to the layer. Grows or shrinks the input by the given scale.
     *
     * Two important points about scale animations:
     * 1) They ARE NOT PERMANENT. If you use an animation to apply a 0.5 scale to an input, then go live or save the layout, the scale does not carry over. If you want to make the change permanent use scaleSize()
     * 2) The scale is relative to the original size of the input. So applying one 2x scale and then another 2x scale only results in the scale changing once.
     */
    this.scaleLayer = function(scaleVal, duration, kwargs) {
        var cval = this.animationLayer.valueForKeyPath('transform.scale');
        var anim_vals = this.make_animation_values(cval, scaleVal, function(x) { return x; });
        return this.simple_animation('transform.scale', anim_vals, duration, kwargs);
    }
    
    /**
     * Changes the input bounds by scaleVal. This change IS permanent; if you save and restore the layout after performing a scaleSize() the input will retain the size it was set to by the animation. 
     * Note that the scaleVal is relative to the CURRENT size of the input, so applying a 2x scaleSize followed by another 2x scaleSize will result in something 4x as big as the original bounds.
     */
    this.scaleSize = function(scaleVal, duration, kwargs) {
        var curr_width = this.width;
        var curr_height = this.height;
        
        
    }
        
    
    /**
     * Set the width of the input. This change saves/is permanent
     * @param {number} width - The input's new width
     */
    this.sizeWidth = function(width, duration, kwargs) {
        kwargs = kwargs || {};
        
        var move_frames = [];
        var original_width = this.width();
        
        var vmk = function(val) {
            var mvval;
            if (kwargs['anchorLeft'])
            {
                mvval = (val - original_width)/2;
            } else if (kwargs['anchorRight']) {
                mvval = (original_width - val)/2;
            }
            if (mvval !== undefined)
            {
                move_frames.push(mvval);
            }
            return val;
        }
        
        var anim_vals = this.make_animation_values(original_width, width, vmk);
        
        kwargs['use_fromVal'] = original_width;
        kwargs['extra_keypath'] = 'bounds.size.width';
        var ret = this.simple_animation('fakeWidth', anim_vals, duration, kwargs);
        delete kwargs['use_fromVal'];
        delete kwargs['extra_keypath'];
        this.moveX(move_frames, duration, kwargs);
        return ret;
    }
        
    
    
    /**
     * Set the height of the input. This change saves/is permanent
     * @param {number} height - The input's new height
     */
    this.sizeHeight = function(height, duration, kwargs) {
        kwargs = kwargs || {};
        
        var move_frames = [];
        var original_height = this.height();
        
        var vmk = function(val) {
            var mvval;
            if (kwargs['anchorBottom'])
            {
                mvval = (val - original_height)/2;
            } else if (kwargs['anchorTop']) {
                mvval = (original_height - val)/2;
            }
            if (mvval !== undefined)
            {
                move_frames.push(mvval);
            }
            return val;
        }
        
        var anim_vals = this.make_animation_values(original_height, height, vmk);
        
        kwargs['use_fromVal'] = original_height;
        kwargs['extra_keypath'] = 'bounds.size.height';
        var ret = this.simple_animation('fakeHeight', anim_vals, duration, kwargs);
        delete kwargs['use_fromVal'];
        delete kwargs['extra_keypath'];
        this.moveY(move_frames, duration, kwargs);
        return ret;
    }
        

    /**
     * Set the width and height of the input. This change saves/is permanent. It is applied to the underlying layer's bounds.
     */
    this.size = function(size_map, duration, kwargs) {
        kwargs = kwargs || {};
        
        var width_vals;
        var height_vals;
        if (Array.isArray(size_map))
        {
            width_vals = [];
            height_vals = [];
            size_map.forEach(function (s) {
                             width_vals.push(s.width);
                             height_vals.push(s.height);
                             });
        } else {
            width_vals = size_map.width;
            height_vals = size_map.height;
        }
        
        this.sizeWidth(width_vals, duration, kwargs);
        return this.sizeHeight(height_vals, duration, kwargs);
    }
    
    
    /**
     * Translate/move the input on the y-axis to the new value y. The final result of this translation is not permanent/saved. 
     * If you translate an input and then manually move it via the UI or via the move* functions, it may not restore/go live in the exact position it appears in the layout. 
     * Use caution.
     */
    this.translateYTo = function(y, duration, kwargs) {
    
        kwargs = kwargs || {};
        var cval = this.animationLayer.valueForKeyPath('transform.translation.y');
        var vmk = function(val) {
            var new_coord = this.real_coordinate_from_fract(0, val);
            new_coord = this.adjust_coordinates(0, new_coord.y);
            return new_coord.y + cval;
        }
        
        var anim_vals = this.make_animation_values(0, y, vmk);
        return this.simple_animation('transform.translation.y', anim_vals, duration, kwargs);
    }
    
    /**
     * Translate/move the input on the x-axis to the new value x. The final result of this translation is not permanent/saved.
     * If you translate an input and then manually move it via the UI or via the move* functions, it may not restore/go live in the exact position it appears in the layout.
     * Use caution.
     */
    this.translateXTo = function(x, duration, kwargs) {
            
        kwargs = kwargs || {};
        var cval = this.animationLayer.valueForKeyPath('transform.translation.x');
        var vmk = function(val) {
            var new_coord = this.real_coordinate_from_fract(val,x);
            new_coord = this.adjust_coordinates(new_coord.x, 0);
            return new_coord.x + cval;
        }
            
        var anim_vals = this.make_animation_values(x, 0, vmk);
        return this.simple_animation('transform.translation.x', anim_vals, duration, kwargs);
    }

    
    /**
     * Translate/move the input's origin to the coordinate (x,y) The final result of this translation is not permanent/saved. 
     * If you translate an input and then manually move it via the UI or via the move* functions, it may not restore/go live in the exact position it appears in the layout. 
     * Use caution.
     */
    this.translateTo = function(pos, duration, kwargs) {
        var cpos = this.animationLayer.valueForKeyPath('transform.translation').sizeValue();
        self = this;
        
        var vmk = function(val) {
            var new_coord = self.real_coordinate_from_fract(val.x, val.y);
            new_coord = self.adjust_coordinates(new_coord.x, new_coord.y);
            var nsize = {width: cpos.width+new_coord.x, height: cpos.height+new_coord.y};
            return NSValue.valueWithSize(nsize);
        }
        
        var isize = {width: 0, height: 0};
        var anim_vals = this.make_animation_values(isize, pos, vmk);
        return this.simple_animation('transform.translation', anim_vals, duration, kwargs);
    }
    
    this.translateY = function(y, duration, kwargs) {
        kwargs = kwargs || {};
        var cval = this.animationLayer.valueForKeyPath('transform.translation.y');
        self = this;
        var vmk = function(val) {
            var new_coord = self.real_coordinate_from_fract(0,val);
            return new_coord.y+cval;
        }
        var anim_vals = this.make_animation_values(0,y,vmk);
        return this.simple_animation('transform.translation.y', anim_vals, duration, kwargs);
    }
    
    this.translateX = function(x,duration,kwargs) {
        kwargs = kwargs || {};
        var cval = this.animationLayer.valueForKeyPath('transform.translation.x');
        self = this;
        var vmk = function(val) {
            var new_coord = self.real_coordinate_from_fract(val, 0);
            return new_coord.x+cval;
        }
        var anim_vals = this.make_animation_values(0,x,vmk);
        return this.simple_animation('transform.translation.x', anim_vals, duration, kwargs);
    }
    
    this.translate = function(pos, duration, kwargs) {
        kwargs = kwargs || {};
        
        var cpos = this.animationLayer.valueForKeyPath('transform.translation').sizeValue();
        self = this;
        var vmk = function(val) {
            var new_coord = self.real_coordinate_from_fract(val.x, val.y);
            return {width: cpos.width+new_coord.x, height: cpos.height+new_coord.y};
        }
        var isize = {width: 0, height: 0};
        var anim_vals = this.make_animation_values(isize, pos, vmk);
        return this.simple_animation('transform.translation', anim_vals, duration, kwargs);
    }
    
    /**
     * Translate to the center of the layout. This translate is slight different from the other translate animations; it moves the input's CENTER to the center of the layout. 
     * The final result of this translation is not permanent/saved. If you translate an input and then manually move it via the UI or via the move* functions, it may not restore/go live in the exact position it appears in the layout. 
     * Use caution.
     */
    
    this.translateCenter = function(duration,  kwargs) {
        kwargs = kwargs || {};
        var rootLayer = this.layer.superlayer;
        var rootWidth = rootLayer.bounds.width;
        var rootHeight = rootLayer.bounds.height;
        
        var new_x = rootWidth * 0.5 - this.animationLayer.frame.width * 0.5;
        var new_y = rootHeight * 0.5 - this.animationLayer.frame.height * 0.5;
        return this.translateTo(new_x, new_y, duration, kwargs);
    }
    
    
    this.rotate = function(angle, duration, kwargs) {
        
        var fromVal = this.animationLayer.valueForKeyPath("transform.rotation.z");
        var anim_vals = this.make_animation_values(fromVal, angle, function(x) { return fromVal+(x * Math.PI /180)});
        
        return this.simple_animation("transform.rotation.z", anim_vals, duration, kwargs);
    }
    
    
}
