local Mon3trSkillReplica = Class(function(self, inst)
    self.inst = inst
end)

function Mon3trSkillReplica:IsSkill3Activating()
    return self.inst.replica.ark_skill:IsActivating("skill3")
end

return Mon3trSkillReplica
