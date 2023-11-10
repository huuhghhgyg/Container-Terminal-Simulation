local obj = {
    message = function()
        print('hello world')
    end
}

obj:message()

function obj:message(str)
    print('123')
end

obj:message()